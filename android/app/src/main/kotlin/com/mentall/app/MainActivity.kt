package com.mentall.app

import io.flutter.embedding.android.FlutterFragmentActivity

// O plugin local_auth (via androidx.biometric) exige uma FragmentActivity.
// Com FlutterActivity o BiometricPrompt retorna NOT_FRAGMENT_ACTIVITY, o que
// o plugin traduz para LocalAuthExceptionCode.uiUnavailable — fazendo o app
// cair no fail-safe e informar que o aparelho nao tem biometria.
class MainActivity : FlutterFragmentActivity()
