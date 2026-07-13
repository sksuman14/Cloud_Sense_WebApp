'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "194380137daf0a7ecc7bb35bec8c3c62",
"assets/AssetManifest.bin.json": "724ced769450734261ba476b5a2ad49e",
"assets/AssetManifest.json": "e381662afe80862b0e77aa9d508e416f",
"assets/assets/fonts/DMSerifText-Italic.ttf": "48d9b180aa132af0fe0d8ad1d5f8184d",
"assets/assets/fonts/DMSerifText-Regular.ttf": "26a61f86766bef242af31d725837a52a",
"assets/assets/fonts/OpenSans-Italic-VariableFont_wdth,wght.ttf": "31d95e96058490552ea28f732456d002",
"assets/assets/fonts/OpenSans-VariableFont_wdth,wght.ttf": "78609089d3dad36318ae0190321e6f3e",
"assets/assets/icons/applogo.jpg": "2e94775337b76c86ce1e0f9be0f894ae",
"assets/assets/images/blegateway.png": "52b81742f2e9702c3e3c6dcc458d4fa3",
"assets/assets/images/buffalo_.jpg": "0f21746395163610782b4c3f7a63471a",
"assets/assets/images/buffalo_1.png": "4d3c9fe34f18155ef168a00caddd1e2a",
"assets/assets/images/Chloritronn.png": "63cf58bcf21ab3c4e1479daf44702b6d",
"assets/assets/images/CompassImage2.png": "7c52a0bd9f721c18fc7c61206f0e8cbd",
"assets/assets/images/cow1.png": "7f00e04a63e4645fa29364c61b02b31e",
"assets/assets/images/datalogger.png": "aeae239978d7a4a963debcb1d6d806db",
"assets/assets/images/dataloggerrender.png": "e670a91622fa7efba0168e98c19e9e3b",
"assets/assets/images/gauge.png": "182cfdcc4b2a0d28cb3fb4a22ac4a239",
"assets/assets/images/google.jpeg": "d962dcb461d205a8e11fdc459eae8f1d",
"assets/assets/images/luxpressure.png": "89156c88de30dc5b2e63d9f7b7f03a2b",
"assets/assets/images/signin.png": "5b3d4ea4405249f9b0af5e551035d19c",
"assets/assets/images/signup3.png": "ef4aa80af14539ea5a9abdc416f391ff",
"assets/assets/images/soil.png": "b76c7a1020c4921f69372c6a5a58d3fd",
"assets/assets/images/thprobe.png": "1e816fb23aa182a0c851bab4b6a30ca7",
"assets/assets/images/tree.jpg": "474a61bd17c3381840a5684d707486f3",
"assets/assets/images/ultrasonic.png": "9b96c2bb991bfac1cb271205363e441b",
"assets/assets/images/water_quality.jpg": "b4bf7dfbb24eb7e8caa713f0090c9267",
"assets/assets/images/weather.jpg": "a2925d93156783e99d50f88c8edae958",
"assets/assets/models/data_logger.glb": "478bafade7e6f0bd9523dfdefa014f6b",
"assets/assets/models/probe.glb": "f700d71f076910955d767d519ecc8724",
"assets/assets/models/radiation_shield.glb": "4af2b3bd70b89bb2d53f44f9e983bca0",
"assets/assets/models/raingauge.glb": "b4e27be78a5db42920776174d121bcbc",
"assets/assets/models/ultrasonic.glb": "a750161b592228e57a3316a6ed9a9a6b",
"assets/assets/pdfs/BLE_GATEWAY_Datasheet.pdf": "3735b5f3401d8cb898dab7d06800b7c1",
"assets/assets/pdfs/Data_logger_datasheet.pdf": "1aeb3e2057264e003ddaf84a3d5f1461",
"assets/assets/pdfs/PROBE_DATASHEET.pdf": "3b89ee906c7865e23afa61e2f044b7ff",
"assets/assets/pdfs/RADIATION_SHIELD_DATASHEET.pdf": "69b9c5ff3b98e9f7a6c8377c8a057bf3",
"assets/assets/pdfs/RAIN_GAUGE_DATASHEET.pdf": "4d7b39734f5a885f23f8821744caace6",
"assets/assets/pdfs/Setup_Manual.pdf": "ee1ffee431ff61cd053b73a6326a6344",
"assets/assets/pdfs/SOIL_SPECTRA_DATASHEET.pdf": "7b2d78c687395bd0e19885731f870cce",
"assets/assets/pdfs/ULTRASONIC_DATASHEET.pdf": "ebf5cac764c9ac9042da0cec62a4de11",
"assets/assets/pdfs/User_Manual.pdf": "d051702ccafa71bc8b47f49572823e9e",
"assets/FontManifest.json": "179513f8cdcc671da1d499dcbaaf2491",
"assets/fonts/MaterialIcons-Regular.otf": "e6265680142e9b2b8d48591d781a46f7",
"assets/NOTICES": "15e01a28c585ef1740af3a031d9fbca1",
"assets/packages/amplify_authenticator/assets/social-buttons/google.png": "a1e1d65465c69a65f8d01226ff5237ec",
"assets/packages/amplify_authenticator/assets/social-buttons/SocialIcons.ttf": "1566e823935d5fe33901f5a074480a20",
"assets/packages/amplify_auth_cognito_dart/lib/src/workers/workers.min.js": "ba1640c479f80566a30f0699f3524ca1",
"assets/packages/amplify_auth_cognito_dart/lib/src/workers/workers.min.js.map": "9db73d612f24f17196def9fb76eb7f4f",
"assets/packages/amplify_secure_storage_dart/lib/src/worker/workers.min.js": "9a2b99dd0e5f96670060b4887b9e8c30",
"assets/packages/amplify_secure_storage_dart/lib/src/worker/workers.min.js.map": "ce043277a9386bc85a1141db8c0cfd46",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/fluttertoast/assets/toastify.css": "a85675050054f179444bc5ad70ffc635",
"assets/packages/fluttertoast/assets/toastify.js": "56e2c9cedd97f10e7e5f1cebd85d53e3",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/packages/model_viewer_plus/assets/model-viewer.min.js": "dd677b435b16f44e4ca08a9f354bac24",
"assets/packages/model_viewer_plus/assets/template.html": "8de94ff19fee64be3edffddb412ab63c",
"assets/packages/syncfusion_flutter_charts/assets/fonts/Roboto-Medium.ttf": "58aef543c97bbaf6a9896e8484456d98",
"assets/packages/syncfusion_flutter_charts/assets/fonts/Times-New-Roman.ttf": "e2f6bf4ef7c6443cbb0ae33f1c1a9ccc",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"dbf752dc211e013db688977a8c619739/gen_dart_plugin_registrant.stamp": "436d2f2faeb7041740ee3f49a985d62a",
"dbf752dc211e013db688977a8c619739/gen_localizations.stamp": "436d2f2faeb7041740ee3f49a985d62a",
"dbf752dc211e013db688977a8c619739/_composite.stamp": "436d2f2faeb7041740ee3f49a985d62a",
"favicon.png": "352a05256273593e3e2b5d173d54cf60",
"firebase-messaging-sw.js": "17c44fff535ffea2671fce491d6dd458",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_assets/AssetManifest.bin": "194380137daf0a7ecc7bb35bec8c3c62",
"flutter_assets/AssetManifest.bin.json": "724ced769450734261ba476b5a2ad49e",
"flutter_assets/AssetManifest.json": "e381662afe80862b0e77aa9d508e416f",
"flutter_assets/assets/fonts/DMSerifText-Italic.ttf": "48d9b180aa132af0fe0d8ad1d5f8184d",
"flutter_assets/assets/fonts/DMSerifText-Regular.ttf": "26a61f86766bef242af31d725837a52a",
"flutter_assets/assets/fonts/OpenSans-Italic-VariableFont_wdth,wght.ttf": "31d95e96058490552ea28f732456d002",
"flutter_assets/assets/fonts/OpenSans-VariableFont_wdth,wght.ttf": "78609089d3dad36318ae0190321e6f3e",
"flutter_assets/assets/icons/applogo.jpg": "2e94775337b76c86ce1e0f9be0f894ae",
"flutter_assets/assets/images/blegateway.png": "52b81742f2e9702c3e3c6dcc458d4fa3",
"flutter_assets/assets/images/buffalo_.jpg": "0f21746395163610782b4c3f7a63471a",
"flutter_assets/assets/images/buffalo_1.png": "4d3c9fe34f18155ef168a00caddd1e2a",
"flutter_assets/assets/images/Chloritronn.png": "63cf58bcf21ab3c4e1479daf44702b6d",
"flutter_assets/assets/images/CompassImage2.png": "7c52a0bd9f721c18fc7c61206f0e8cbd",
"flutter_assets/assets/images/cow1.png": "7f00e04a63e4645fa29364c61b02b31e",
"flutter_assets/assets/images/datalogger.png": "aeae239978d7a4a963debcb1d6d806db",
"flutter_assets/assets/images/dataloggerrender.png": "e670a91622fa7efba0168e98c19e9e3b",
"flutter_assets/assets/images/gauge.png": "182cfdcc4b2a0d28cb3fb4a22ac4a239",
"flutter_assets/assets/images/google.jpeg": "d962dcb461d205a8e11fdc459eae8f1d",
"flutter_assets/assets/images/luxpressure.png": "89156c88de30dc5b2e63d9f7b7f03a2b",
"flutter_assets/assets/images/signin.png": "5b3d4ea4405249f9b0af5e551035d19c",
"flutter_assets/assets/images/signup3.png": "ef4aa80af14539ea5a9abdc416f391ff",
"flutter_assets/assets/images/soil.png": "b76c7a1020c4921f69372c6a5a58d3fd",
"flutter_assets/assets/images/thprobe.png": "1e816fb23aa182a0c851bab4b6a30ca7",
"flutter_assets/assets/images/tree.jpg": "474a61bd17c3381840a5684d707486f3",
"flutter_assets/assets/images/ultrasonic.png": "9b96c2bb991bfac1cb271205363e441b",
"flutter_assets/assets/images/water_quality.jpg": "b4bf7dfbb24eb7e8caa713f0090c9267",
"flutter_assets/assets/images/weather.jpg": "a2925d93156783e99d50f88c8edae958",
"flutter_assets/assets/models/data_logger.glb": "478bafade7e6f0bd9523dfdefa014f6b",
"flutter_assets/assets/models/probe.glb": "f700d71f076910955d767d519ecc8724",
"flutter_assets/assets/models/radiation_shield.glb": "4af2b3bd70b89bb2d53f44f9e983bca0",
"flutter_assets/assets/models/raingauge.glb": "b4e27be78a5db42920776174d121bcbc",
"flutter_assets/assets/models/ultrasonic.glb": "a750161b592228e57a3316a6ed9a9a6b",
"flutter_assets/assets/pdfs/BLE_GATEWAY_Datasheet.pdf": "3735b5f3401d8cb898dab7d06800b7c1",
"flutter_assets/assets/pdfs/Data_logger_datasheet.pdf": "1aeb3e2057264e003ddaf84a3d5f1461",
"flutter_assets/assets/pdfs/PROBE_DATASHEET.pdf": "3b89ee906c7865e23afa61e2f044b7ff",
"flutter_assets/assets/pdfs/RADIATION_SHIELD_DATASHEET.pdf": "69b9c5ff3b98e9f7a6c8377c8a057bf3",
"flutter_assets/assets/pdfs/RAIN_GAUGE_DATASHEET.pdf": "4d7b39734f5a885f23f8821744caace6",
"flutter_assets/assets/pdfs/Setup_Manual.pdf": "ee1ffee431ff61cd053b73a6326a6344",
"flutter_assets/assets/pdfs/SOIL_SPECTRA_DATASHEET.pdf": "7b2d78c687395bd0e19885731f870cce",
"flutter_assets/assets/pdfs/ULTRASONIC_DATASHEET.pdf": "ebf5cac764c9ac9042da0cec62a4de11",
"flutter_assets/assets/pdfs/User_Manual.pdf": "d051702ccafa71bc8b47f49572823e9e",
"flutter_assets/FontManifest.json": "179513f8cdcc671da1d499dcbaaf2491",
"flutter_assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
"flutter_assets/NOTICES": "15e01a28c585ef1740af3a031d9fbca1",
"flutter_assets/packages/amplify_authenticator/assets/social-buttons/google.png": "a1e1d65465c69a65f8d01226ff5237ec",
"flutter_assets/packages/amplify_authenticator/assets/social-buttons/SocialIcons.ttf": "1566e823935d5fe33901f5a074480a20",
"flutter_assets/packages/amplify_auth_cognito_dart/lib/src/workers/workers.min.js": "6cc11d714dc83e41c4d1c8d51ca2be9b",
"flutter_assets/packages/amplify_auth_cognito_dart/lib/src/workers/workers.min.js.map": "9db73d612f24f17196def9fb76eb7f4f",
"flutter_assets/packages/amplify_secure_storage_dart/lib/src/worker/workers.min.js": "d48749f0a6195646e35ad689c33ef041",
"flutter_assets/packages/amplify_secure_storage_dart/lib/src/worker/workers.min.js.map": "ce043277a9386bc85a1141db8c0cfd46",
"flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"flutter_assets/packages/fluttertoast/assets/toastify.css": "910ddaaf9712a0b0392cf7975a3b7fb5",
"flutter_assets/packages/fluttertoast/assets/toastify.js": "18cfdd77033aa55d215e8a78c090ba89",
"flutter_assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"flutter_assets/packages/model_viewer_plus/assets/model-viewer.min.js": "d616006d2f9f75ca4b0bcee8b0fb30c7",
"flutter_assets/packages/model_viewer_plus/assets/template.html": "24a1f29951029adea5122572451138fc",
"flutter_assets/packages/syncfusion_flutter_charts/assets/fonts/Roboto-Medium.ttf": "58aef543c97bbaf6a9896e8484456d98",
"flutter_assets/packages/syncfusion_flutter_charts/assets/fonts/Times-New-Roman.ttf": "e2f6bf4ef7c6443cbb0ae33f1c1a9ccc",
"flutter_assets/packages/wakelock_plus/assets/no_sleep.js": "9c3aa3cd0b217305aa860decab3d9f42",
"flutter_assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"flutter_bootstrap.js": "12ac9d1be8c5f1eb5f1cabab65c0cbf6",
"icons/Icon-192.png": "90a948ad88bf1c17a5a40ed40bf4905a",
"icons/Icon-512.png": "76feaf63bcbf28ae35c368fa70d14ce7",
"icons/Icon-maskable-192.png": "90a948ad88bf1c17a5a40ed40bf4905a",
"icons/Icon-maskable-512.png": "76feaf63bcbf28ae35c368fa70d14ce7",
"index.html": "4b65c9f85c76b01461b3479d7354a8b5",
"/": "4b65c9f85c76b01461b3479d7354a8b5",
"main.dart.js": "4b04aa0cb08363c35d4b5acc65b35540",
"manifest.json": "93d60bccdcdb08270ee70427510365db",
"maskable": "d41d8cd98f00b204e9800998ecf8427e",
"mobile-app.png": "c2b1747bda9c67c734ff806e5bf0e684",
"model-viewer.min.js": "8073c882ae28be9de881c5b7a63340bf",
"smartphone.png": "07c28484887d1e8f958e7975763a2d2b",
"vercel.json": "af5c9a62a01d43903b69be83782f6859",
"version.json": "559dabe10b1faef090bfc8c4a531889a"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
