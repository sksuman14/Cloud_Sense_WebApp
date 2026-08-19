'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "1ea4ac114bd3593271ee7daebb20374d",
"assets/AssetManifest.bin.json": "f2965fedc6d8ea14cacaaf75d8237ed7",
"assets/AssetManifest.json": "e860461ce46e713f7ac8c69cd75a2a9a",
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
"assets/assets/images/site1.jpg": "303282ac34159bd4a2fcbb91910d618d",
"assets/assets/images/site10.jpg": "865f84dfe5d14c93608e014022544fc7",
"assets/assets/images/site11.jpg": "bb1a528dbe515afc4145336259b13527",
"assets/assets/images/site2.jpg": "9e29cb62b090dacf072c989a688ac3a2",
"assets/assets/images/site3.jpg": "f5a0778debffbd2227ceb33b931418d9",
"assets/assets/images/site4.jpg": "fbda42aca18de511a107a1621ab1d5ad",
"assets/assets/images/site5.jpg": "f12b47070a7e6a9a47da5ac13c2d8afd",
"assets/assets/images/site6.jpg": "17574fc926822245dffff8ac5f123d80",
"assets/assets/images/site7.jpg": "8707a17968cc7f482075bb602e98ff86",
"assets/assets/images/site8.jpg": "a1701da3dff3ec94a3a178ba7da4e3bd",
"assets/assets/images/site9.jpg": "6b3868715a1ce61c2c4ff3c8cf45c780",
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
"assets/FontManifest.json": "96bc6d340384517e40c7b49a5bccb525",
"assets/fonts/MaterialIcons-Regular.otf": "38500843e38a555eabfca195b44c4001",
"assets/NOTICES": "8d07a064ac0b78960ef0070c70d64bca",
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
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "352a05256273593e3e2b5d173d54cf60",
"firebase-messaging-sw.js": "17c44fff535ffea2671fce491d6dd458",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "9fdbf2a15ead59f99fc9807b5ba0111d",
"icons/Icon-192.png": "90a948ad88bf1c17a5a40ed40bf4905a",
"icons/Icon-512.png": "76feaf63bcbf28ae35c368fa70d14ce7",
"icons/Icon-maskable-192.png": "90a948ad88bf1c17a5a40ed40bf4905a",
"icons/Icon-maskable-512.png": "76feaf63bcbf28ae35c368fa70d14ce7",
"index.html": "4b65c9f85c76b01461b3479d7354a8b5",
"/": "4b65c9f85c76b01461b3479d7354a8b5",
"main.dart.js": "d701a8228f47dfe57769ce7ed50ee52e",
"manifest.json": "93d60bccdcdb08270ee70427510365db",
"maskable": "d41d8cd98f00b204e9800998ecf8427e",
"mobile-app.png": "c2b1747bda9c67c734ff806e5bf0e684",
"model-viewer.min.js": "129bdd53ae0634880991acf8d0f0d9dc",
"smartphone.png": "07c28484887d1e8f958e7975763a2d2b",
"vercel.json": "af5c9a62a01d43903b69be83782f6859",
"version.json": "d456adf03a6a3c4a40206e6429013150"};
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
