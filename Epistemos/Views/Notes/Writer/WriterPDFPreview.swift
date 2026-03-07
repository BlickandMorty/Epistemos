import PDFKit
import SwiftUI

// MARK: - WriterPDFPreview
// Wraps PDFView for live PDF preview in writer mode.
// Receives a PDFDocument and displays it with thumbnail sidebar.

struct WriterPDFPreview: NSViewRepresentable {

    let pdfDocument: PDFDocument?

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        pdfView.document = pdfDocument
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== pdfDocument {
            pdfView.document = pdfDocument
        }
    }
}
