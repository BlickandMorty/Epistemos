// W7.17 Tiptap WKWebView bundle build
//
// Single config; --mode prod/dev branches inside the export. Outputs
// land at dist/ which build-tiptap-bundle.sh rsyncs to
// Epistemos/Resources/Editor/ so EpdocEditorURLSchemeHandler resolves
// epistemos-doc:///editor.html, /editor.js, /editor.css, /vendor/katex/...

const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');

module.exports = (_env, argv) => ({
  // WKWebView, NOT Node — disable Node-style polyfills.
  target: 'web',
  entry: { editor: './src/index.ts' },
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].js',
    publicPath: '/',                          // matches epistemos-doc:///*
    clean: true,
    assetModuleFilename: 'assets/[name][ext]',
  },
  resolve: { extensions: ['.ts', '.tsx', '.js', '.mjs'] },
  module: {
    rules: [
      { test: /\.tsx?$/, loader: 'ts-loader', options: { transpileOnly: false } },
      { test: /\.css$/, use: [MiniCssExtractPlugin.loader, 'css-loader'] },
      // KaTeX fonts shipped as separate assets the URLSchemeHandler can serve.
      // The MIME table in EpdocEditorBridge.swift already maps woff2 → font/woff2.
      { test: /\.(woff2?|ttf)$/i, type: 'asset/resource',
        generator: { filename: 'vendor/katex/fonts/[name][ext]' } },
    ],
  },
  plugins: [
    new MiniCssExtractPlugin({ filename: 'editor.css' }),
    new HtmlWebpackPlugin({
      template: './src/editor.html',
      filename: 'editor.html',
      inject: 'body',
      scriptLoading: 'blocking',              // WKWebView mounts deterministically
    }),
    new CopyPlugin({
      patterns: [
        // KaTeX CSS sets font URLs relative to the CSS — copy fonts so paths work
        { from: 'node_modules/katex/dist/fonts', to: 'vendor/katex/fonts' },
        { from: 'node_modules/katex/dist/katex.min.css', to: 'vendor/katex/katex.min.css' },
        // Pre-bundled Mermaid (W7.9) — vendor copy avoids dynamic import
        // chunks, which WKWebView's CSP-default refuses.
        { from: 'node_modules/mermaid/dist/mermaid.min.js', to: 'vendor/mermaid/mermaid.min.js' },
      ],
    }),
  ],
  devtool: argv.mode === 'production' ? false : 'inline-source-map',
  performance: { hints: false },              // editor.js ~400 KB gz expected
  optimization: { minimize: argv.mode === 'production' },
});
