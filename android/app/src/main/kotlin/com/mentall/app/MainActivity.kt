package com.mentall.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// O plugin local_auth (via androidx.biometric) exige uma FragmentActivity.
// Com FlutterActivity o BiometricPrompt retorna NOT_FRAGMENT_ACTIVITY, o que
// o plugin traduz para LocalAuthExceptionCode.uiUnavailable — fazendo o app
// cair no fail-safe e informar que o aparelho nao tem biometria.
//
// Alem disso, esta Activity expoe um canal ("mentall/backup_saf") para que o
// app grave os backups automáticos em uma pasta escolhida pelo usuário usando
// Storage Access Framework (DocumentFile/ContentResolver). Sem isso, uma pasta
// fora do diretório privado do app falhava com "Permission denied" (o caminho
// devolvido pelo seletor não é gravável por dart:io no Android 11+).
class MainActivity : FlutterFragmentActivity() {

    private val canalBackup = "mentall/backup_saf"
    private val pedidoPasta = 4701
    private var resultadoPendente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canalBackup)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> abrirSeletorPasta(result)
                    "writeFile" -> gravarArquivo(call, result)
                    "testDirectory" -> testarPasta(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun abrirSeletorPasta(result: MethodChannel.Result) {
        if (resultadoPendente != null) {
            result.error("ocupado", "Já existe um seletor de pasta aberto.", null)
            return
        }
        resultadoPendente = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        try {
            startActivityForResult(intent, pedidoPasta)
        } catch (e: Exception) {
            resultadoPendente = null
            result.error("seletor", e.message ?: "Não foi possível abrir o seletor.", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pedidoPasta) return
        val result = resultadoPendente ?: return
        resultadoPendente = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: Exception) {
            // Alguns provedores não aceitam persistência; seguimos com a permissão
            // temporária desta sessão.
        }
        result.success(
            mapOf(
                "uri" to uri.toString(),
                "name" to nomeDaPasta(uri),
            )
        )
    }

    private fun nomeDaPasta(uri: Uri): String {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(uri)
            val docUri = DocumentsContract.buildDocumentUriUsingTree(uri, docId)
            contentResolver.query(
                docUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else "Pasta escolhida"
            } ?: "Pasta escolhida"
        } catch (_: Exception) {
            uri.lastPathSegment ?: "Pasta escolhida"
        }
    }

    private fun acharDocumento(uriArvore: Uri, nome: String): Uri? {
        return try {
            val idArvore = DocumentsContract.getTreeDocumentId(uriArvore)
            val filhos = DocumentsContract.buildChildDocumentsUriUsingTree(uriArvore, idArvore)
            contentResolver.query(
                filhos,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                ),
                null, null, null
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (cursor.getString(1) == nome) {
                        return DocumentsContract.buildDocumentUriUsingTree(
                            uriArvore, cursor.getString(0)
                        )
                    }
                }
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun gravarArquivo(call: MethodCall, result: MethodChannel.Result) {
        val uriArvore = call.argument<String>("uri")
        val nome = call.argument<String>("name")
        val conteudo = call.argument<String>("content")
        if (uriArvore.isNullOrBlank() || nome.isNullOrBlank() || conteudo == null) {
            result.error("args", "Argumentos ausentes para gravar o backup.", null)
            return
        }
        try {
            val arvore = Uri.parse(uriArvore)
            val idArvore = DocumentsContract.getTreeDocumentId(arvore)
            val docArvore = DocumentsContract.buildDocumentUriUsingTree(arvore, idArvore)
            val existente = acharDocumento(arvore, nome)
            val destino = existente
                ?: DocumentsContract.createDocument(
                    contentResolver, docArvore, "application/json", nome
                )
                ?: throw IllegalStateException("Sem permissão para criar o arquivo na pasta escolhida.")
            contentResolver.openOutputStream(destino, "wt")?.use { saida ->
                saida.write(conteudo.toByteArray(Charsets.UTF_8))
                saida.flush()
            } ?: throw IllegalStateException("Sem permissão de escrita na pasta escolhida.")
            result.success(destino.toString())
        } catch (e: Exception) {
            result.error("gravar", e.message ?: "Falha ao gravar o backup.", null)
        }
    }

    private fun testarPasta(call: MethodCall, result: MethodChannel.Result) {
        val uriArvore = call.argument<String>("uri")
        if (uriArvore.isNullOrBlank()) {
            result.error("args", "Pasta não informada.", null)
            return
        }
        try {
            val arvore = Uri.parse(uriArvore)
            val idArvore = DocumentsContract.getTreeDocumentId(arvore)
            val docArvore = DocumentsContract.buildDocumentUriUsingTree(arvore, idArvore)
            val nomeTeste = ".mentall-teste-escrita.json"
            acharDocumento(arvore, nomeTeste)?.let { antigo ->
                runCatching { DocumentsContract.deleteDocument(contentResolver, antigo) }
            }
            val teste = DocumentsContract.createDocument(
                contentResolver, docArvore, "application/json", nomeTeste
            ) ?: throw IllegalStateException("A pasta não permite gravação direta.")
            contentResolver.openOutputStream(teste, "wt")?.use { saida ->
                saida.write("{}".toByteArray(Charsets.UTF_8))
                saida.flush()
            } ?: throw IllegalStateException("A pasta não permite gravação direta.")
            runCatching { DocumentsContract.deleteDocument(contentResolver, teste) }
            result.success(true)
        } catch (e: Exception) {
            result.error("teste", e.message ?: "A pasta não permite gravação direta.", null)
        }
    }
}
