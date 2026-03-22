#!/usr/bin/env python3

import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("build_retrieval_index.py")
SPEC = importlib.util.spec_from_file_location("build_retrieval_index", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class BuildRetrievalIndexTests(unittest.TestCase):
    def make_db(self) -> Path:
        temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(temp_dir.cleanup)
        db_path = Path(temp_dir.name) / "search.sqlite"
        connection = sqlite3.connect(db_path)
        self.addCleanup(connection.close)
        connection.execute(
            """
            CREATE TABLE indexed_pages (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                tags TEXT,
                updatedAt REAL NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE indexed_blocks (
                block_id TEXT PRIMARY KEY,
                page_id TEXT NOT NULL,
                content TEXT NOT NULL
            )
            """
        )
        connection.commit()
        return db_path

    def test_falls_back_to_indexed_pages_when_blocks_are_empty(self) -> None:
        db_path = self.make_db()
        connection = sqlite3.connect(db_path)
        self.addCleanup(connection.close)
        connection.execute(
            """
            INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
            VALUES ('page-1', 'Title', 'Body text', '', 1)
            """
        )
        connection.commit()

        self.assertEqual(MODULE.select_corpus_source(connection), "pages")
        batches = list(MODULE.iter_corpus_documents(str(db_path), batch_size=10, max_docs=0))

        self.assertEqual(len(batches), 1)
        self.assertEqual(batches[0][0]["source_type"], "page")
        self.assertIsNone(batches[0][0]["block_id"])
        self.assertEqual(batches[0][0]["page_id"], "page-1")
        self.assertEqual(batches[0][0]["content"], "Title\n\nBody text")

    def test_prefers_indexed_blocks_when_block_corpus_exists(self) -> None:
        db_path = self.make_db()
        connection = sqlite3.connect(db_path)
        self.addCleanup(connection.close)
        connection.execute(
            """
            INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
            VALUES ('page-1', 'Title', 'Body text', '', 1)
            """
        )
        connection.execute(
            """
            INSERT INTO indexed_blocks (block_id, page_id, content)
            VALUES ('block-1', 'page-1', 'Chunk text')
            """
        )
        connection.commit()

        self.assertEqual(MODULE.select_corpus_source(connection), "blocks")
        batches = list(MODULE.iter_corpus_documents(str(db_path), batch_size=10, max_docs=0))

        self.assertEqual(len(batches), 1)
        self.assertEqual(batches[0][0]["source_type"], "block")
        self.assertEqual(batches[0][0]["block_id"], "block-1")
        self.assertEqual(batches[0][0]["page_id"], "page-1")
        self.assertEqual(batches[0][0]["content"], "Chunk text")

    def test_source_database_snapshot_tracks_database_and_wal_mtime(self) -> None:
        db_path = self.make_db()
        wal_path = Path(f"{db_path}-wal")
        wal_path.write_bytes(b"wal")
        self.addCleanup(lambda: wal_path.unlink(missing_ok=True))

        snapshot = MODULE.source_database_snapshot(str(db_path))

        self.assertEqual(snapshot["sourceDatabasePath"], str(db_path.resolve()))
        self.assertIsInstance(snapshot["sourceDatabaseModifiedAt"], float)
        self.assertIsInstance(snapshot["sourceDatabaseWALModifiedAt"], float)


if __name__ == "__main__":
    unittest.main()
