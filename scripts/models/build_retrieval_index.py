#!/usr/bin/env python3

import argparse
import inspect
import json
import sqlite3
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a prepared retrieval index from the live search.sqlite block corpus."
    )
    parser.add_argument("--database", required=True, help="Path to search.sqlite")
    parser.add_argument("--retriever", required=True, help="Path to the downloaded BGE retriever")
    parser.add_argument("--output-dir", required=True, help="Directory for documents.jsonl and block-embeddings.f32")
    parser.add_argument("--retriever-model-id", required=True)
    parser.add_argument("--reranker-model-id", default="")
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--max-length", type=int, default=1024)
    parser.add_argument("--max-docs", type=int, default=0)
    return parser.parse_args()


def load_encoder(model_path: str):
    try:
        from FlagEmbedding import BGEM3FlagModel
    except Exception:
        try:
            from sentence_transformers import SentenceTransformer
        except ImportError as exc:
            raise SystemExit(
                "Missing Python modules: FlagEmbedding or sentence_transformers. "
                "Install one of them in the model-prep environment before building the retrieval index."
            ) from exc
        model = SentenceTransformer(model_path, trust_remote_code=True)
        if hasattr(model, "max_seq_length"):
            model.max_seq_length = 8192
        return model

    return BGEM3FlagModel(model_path, use_fp16=False)


def table_exists(connection: sqlite3.Connection, name: str) -> bool:
    row = connection.execute(
        "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?)",
        (name,),
    ).fetchone()
    return bool(row and row[0])


def select_corpus_source(connection: sqlite3.Connection) -> str:
    if table_exists(connection, "indexed_blocks"):
        row = connection.execute(
            "SELECT EXISTS(SELECT 1 FROM indexed_blocks WHERE trim(content) <> '')"
        ).fetchone()
        if row and row[0]:
            return "blocks"

    if table_exists(connection, "indexed_pages"):
        row = connection.execute(
            """
            SELECT EXISTS(
                SELECT 1
                FROM indexed_pages
                WHERE trim(
                    CASE
                        WHEN trim(title) <> '' AND trim(body) <> '' THEN title || '\n\n' || body
                        WHEN trim(body) <> '' THEN body
                        ELSE title
                    END
                ) <> ''
            )
            """
        ).fetchone()
        if row and row[0]:
            return "pages"

    raise SystemExit("No searchable indexed_blocks or indexed_pages rows were available to build a retrieval index.")


def iter_corpus_documents(db_path: str, batch_size: int, max_docs: int):
    connection = sqlite3.connect(db_path)
    try:
        source = select_corpus_source(connection)
        if source == "blocks":
            cursor = connection.execute(
                """
                SELECT block_id, page_id, content
                FROM indexed_blocks
                WHERE trim(content) <> ''
                ORDER BY rowid
                """
            )
        else:
            cursor = connection.execute(
                """
                SELECT
                    id,
                    id,
                    CASE
                        WHEN trim(title) <> '' AND trim(body) <> '' THEN title || '\n\n' || body
                        WHEN trim(body) <> '' THEN body
                        ELSE title
                    END AS content
                FROM indexed_pages
                WHERE trim(
                    CASE
                        WHEN trim(title) <> '' AND trim(body) <> '' THEN title || '\n\n' || body
                        WHEN trim(body) <> '' THEN body
                        ELSE title
                    END
                ) <> ''
                ORDER BY rowid
                """
            )
        emitted = 0
        while True:
            remaining = max_docs - emitted if max_docs > 0 else batch_size
            fetch_count = min(batch_size, remaining) if max_docs > 0 else batch_size
            if fetch_count <= 0:
                break
            rows = cursor.fetchmany(fetch_count)
            if not rows:
                break
            documents = []
            for document_id, page_id, content in rows:
                documents.append(
                    {
                        "document_id": document_id,
                        "block_id": document_id if source == "blocks" else None,
                        "page_id": page_id,
                        "content": content,
                        "source_type": "block" if source == "blocks" else "page",
                    }
                )
            emitted += len(documents)
            yield documents
            if max_docs > 0 and emitted >= max_docs:
                break
    finally:
        connection.close()


def dense_embeddings(model, texts, max_length: int):
    encode_signature = inspect.signature(model.encode)
    encode_kwargs = {"batch_size": len(texts)}
    if "max_length" in encode_signature.parameters:
        encode_kwargs["max_length"] = max_length
    else:
        if hasattr(model, "max_seq_length"):
            model.max_seq_length = max_length
        encode_kwargs["convert_to_numpy"] = True
        encode_kwargs["normalize_embeddings"] = False
        if "show_progress_bar" in encode_signature.parameters:
            encode_kwargs["show_progress_bar"] = False

    encoded = model.encode(texts, **encode_kwargs)
    dense = encoded.get("dense_vecs") if isinstance(encoded, dict) else encoded
    if dense is None:
        raise SystemExit("Retriever returned no dense vectors for the current batch.")
    try:
        import numpy as np
    except ImportError as exc:
        raise SystemExit(
            "Missing Python module: numpy. "
            "Install it in the model-prep environment before building the retrieval index."
        ) from exc
    array = np.asarray(dense, dtype=np.float32)
    if array.ndim != 2 or array.shape[0] != len(texts):
        raise SystemExit(f"Unexpected dense embedding shape: {array.shape!r}")
    return array


def file_mtime(path: Path):
    try:
        return path.stat().st_mtime
    except FileNotFoundError:
        return None


def source_database_snapshot(database_path: str):
    db_path = Path(database_path).expanduser().resolve()
    wal_path = Path(f"{db_path}-wal")
    return {
        "sourceDatabasePath": str(db_path),
        "sourceDatabaseModifiedAt": file_mtime(db_path),
        "sourceDatabaseWALModifiedAt": file_mtime(wal_path),
    }


def main() -> None:
    args = parse_args()

    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    documents_path = output_dir / "documents.jsonl"
    embeddings_path = output_dir / "block-embeddings.f32"
    manifest_path = output_dir / "manifest.json"

    model = load_encoder(args.retriever)

    document_count = 0
    embedding_dimension = 0

    with documents_path.open("w", encoding="utf-8") as documents_fh, embeddings_path.open("wb") as embeddings_fh:
        for batch in iter_corpus_documents(
            args.database,
            batch_size=max(1, args.batch_size),
            max_docs=max(0, args.max_docs),
        ):
            texts = []
            for document in batch:
                texts.append(document["content"])
                documents_fh.write(
                    json.dumps(document, ensure_ascii=False)
                )
                documents_fh.write("\n")

            matrix = dense_embeddings(model, texts, max_length=max(1, args.max_length))
            if embedding_dimension == 0:
                embedding_dimension = int(matrix.shape[1])
            elif embedding_dimension != int(matrix.shape[1]):
                raise SystemExit(
                    f"Inconsistent embedding dimension: expected {embedding_dimension}, got {matrix.shape[1]}"
                )
            matrix.tofile(embeddings_fh)
            document_count += len(batch)

    if document_count <= 0 or embedding_dimension <= 0:
        raise SystemExit("No indexed blocks were available to build a retrieval index.")

    database_snapshot = source_database_snapshot(args.database)
    manifest = {
        "version": 1,
        "retrieverModelID": args.retriever_model_id,
        "rerankerModelID": args.reranker_model_id or None,
        "embeddingFormat": "row-major-f32-v1",
        "embeddingDimension": embedding_dimension,
        "documentCount": document_count,
        "embeddingsFile": embeddings_path.name,
        "documentsFile": documents_path.name,
        "builtAt": time.time(),
        "sourceDatabasePath": database_snapshot["sourceDatabasePath"],
        "sourceDatabaseModifiedAt": database_snapshot["sourceDatabaseModifiedAt"],
        "sourceDatabaseWALModifiedAt": database_snapshot["sourceDatabaseWALModifiedAt"],
    }
    with manifest_path.open("w", encoding="utf-8") as manifest_fh:
        json.dump(manifest, manifest_fh, indent=2, sort_keys=True)
        manifest_fh.write("\n")

    print(
        json.dumps(
            {
                "documents": str(documents_path),
                "embeddings": str(embeddings_path),
                "manifest": str(manifest_path),
                "documentCount": document_count,
                "embeddingDimension": embedding_dimension,
            }
        )
    )


if __name__ == "__main__":
    main()
