#!/usr/bin/env python3
"""flutter create'in ürettiği Android klasörüne Terazi ayarlarını uygular.

- Ad: "Terazi" (Play Store adı "Terazi: Gelir Gider Takibi").
- Bildirim: izinler ve flutter_local_notifications alıcıları (zamanlanmış bildirim, yeniden başlatma, düğmeler).
- Bildirim simgesi platform/android/ klasöründen gelir (res/drawable-*/ic_bildirim.png).
- flutter_local_notifications için Java kütüphane desugaring'i.
- OA_KEYSTORE_PATH ve OA_KEYSTORE_PASSWORD varsa yayın sürümü sabit OA anahtarıyla imzalanır.

Kullanım (proje kökünde): python3 scripts/android_ayarla.py
"""
import os
import re
import shutil
import sys

MANIFEST = 'android/app/src/main/AndroidManifest.xml'

PERMS = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
]

RECEIVERS = '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
'''


def manifest():
    s = open(MANIFEST, encoding='utf-8').read()
    for p in PERMS:
        if p + '"' not in s:
            s = s.replace('<application', '<uses-permission android:name="%s"/>\n    <application' % p, 1)
    if 'ScheduledNotificationReceiver' not in s:
        s = s.replace('</application>', RECEIVERS + '    </application>', 1)
    if 'android:label="terazi"' not in s and 'android:label="Terazi"' not in s:
        sys.exit('AndroidManifest.xml içinde uygulama adı bulunamadı')
    s = s.replace('android:label="terazi"', 'android:label="Terazi"')
    open(MANIFEST, 'w', encoding='utf-8').write(s)
    print('Manifest: izinler, bildirim alıcıları ve ad ayarlandı')


def kaynaklar():
    shutil.copytree('platform/android/app/src/main', 'android/app/src/main', dirs_exist_ok=True)
    print('Android: bildirim simgesi kopyalandı')


PROGUARD = '''
# flutter_local_notifications zamanlanmış bildirimleri Gson ile saklar; küçültme aracı tür bilgisini silerse
# "Missing type parameter" ile çöker.
-keepattributes Signature
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
'''


def gradle():
    rules = 'android/app/proguard-rules.pro'
    old = open(rules, encoding='utf-8').read() if os.path.exists(rules) else ''
    if 'com.dexterous' not in old:
        open(rules, 'w', encoding='utf-8').write(old + PROGUARD)
    kts = 'android/app/build.gradle.kts'
    groovy = 'android/app/build.gradle'
    if os.path.exists(kts):
        s = open(kts, encoding='utf-8').read()
        if 'isCoreLibraryDesugaringEnabled' not in s:
            s, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', s, count=1)
            if n == 0:
                sys.exit('build.gradle.kts içinde compileOptions bulunamadı')
        if 'desugar_jdk_libs' not in s:
            s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        open(kts, 'w', encoding='utf-8').write(s)
    elif os.path.exists(groovy):
        s = open(groovy, encoding='utf-8').read()
        if 'coreLibraryDesugaringEnabled' not in s:
            s, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', s, count=1)
            if n == 0:
                sys.exit('build.gradle içinde compileOptions bulunamadı')
        if 'desugar_jdk_libs' not in s:
            s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        open(groovy, 'w', encoding='utf-8').write(s)
    else:
        sys.exit('android/app/build.gradle(.kts) bulunamadı')
    print('Gradle: desugaring ve küçültme kuralları eklendi')


def signing():
    path = os.environ.get('OA_KEYSTORE_PATH')
    if not path or not os.environ.get('OA_KEYSTORE_PASSWORD'):
        print('::warning title=imza::Sabit imza anahtarı yok (ANDROID_KEYSTORE_BASE64 secret). '
              'APK test anahtarıyla imzalanıyor; Android güncellemeyi eski sürümün üzerine kurmaz.')
        return
    kts = 'android/app/build.gradle.kts'
    groovy = 'android/app/build.gradle'
    if os.path.exists(kts):
        s = open(kts, encoding='utf-8').read()
        block = '''    signingConfigs {
        create("oa") {
            storeFile = file(System.getenv("OA_KEYSTORE_PATH"))
            storePassword = System.getenv("OA_KEYSTORE_PASSWORD")
            keyAlias = "oa"
            keyPassword = System.getenv("OA_KEYSTORE_PASSWORD")
        }
    }
'''
        if 'create("oa")' not in s:
            s = re.sub(r'(^android\s*\{\s*\n)', lambda m: m.group(1) + block, s, count=1, flags=re.M)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = signingConfigs.getByName("oa")')
        open(kts, 'w', encoding='utf-8').write(s)
    elif os.path.exists(groovy):
        s = open(groovy, encoding='utf-8').read()
        block = '''    signingConfigs {
        oa {
            storeFile file(System.getenv("OA_KEYSTORE_PATH"))
            storePassword System.getenv("OA_KEYSTORE_PASSWORD")
            keyAlias "oa"
            keyPassword System.getenv("OA_KEYSTORE_PASSWORD")
        }
    }
'''
        if 'signingConfigs {' not in s:
            s = re.sub(r'(^android\s*\{\s*\n)', lambda m: m.group(1) + block, s, count=1, flags=re.M)
        s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.oa')
        open(groovy, 'w', encoding='utf-8').write(s)
    else:
        sys.exit('android/app/build.gradle(.kts) bulunamadı')
    print('İmza: yayın sürümü sabit OA anahtarıyla imzalanacak')


if __name__ == '__main__':
    manifest()
    kaynaklar()
    gradle()
    signing()
