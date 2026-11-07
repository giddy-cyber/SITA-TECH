const VERSION = 'v5';
const CACHE = `sita-tech-${VERSION}`;
const PRECACHE = [
  './',
  './index.html',
  './free-tools.html',
  './manifest.webmanifest',
  './favicon.ico',
  './favicon-16x16.png',
  './favicon-32x32.png',
  './favicon-48x48.png',
  './favicon-96x96.png',
  './apple-touch-icon.png',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './images/tool-whatsapp-link.webp',
  './images/tool-qr-code.webp',
  './images/tool-passport-crop.webp',
  './images/tool-image-resize.webp',
  './images/tool-file-converter.webp',
  './images/tool-image-compress.webp',
  './images/tool-pdf.webp',
  './images/tool-cv.webp',
  './images/tool-shop-logo.webp',
  './images/svc-kuccps.webp',
  './images/svc-nssf.webp',
  './images/svc-ecitizen.webp',
  './images/svc-itax.webp',
  './images/svc-ntsa.webp',
  './images/svc-windows.webp',
  './images/svc-printer.webp',
  './images/svc-wifi.webp',
  './images/svc-repair.webp',
  './images/svc-nurseiv.webp',
  './images/svc-nursecare.webp',
  './images/svc-bpcheck.webp',
  './images/svc-sha.webp',
  './images/svc-cv.webp',
  './images/svc-website.webp',
  './images/svc-hikvision.webp',
  './images/svc-typing.webp',
  './images/svc-antivirus.webp',
  './images/svc-designer.webp',
  './images/svc-ziora.webp',
  './images/svc-beautycard.webp',
  './images/svc-goldcard.webp',
  './images/svc-excel.webp',
  './images/svc-businessman.webp',
  './images/svc-scanner.webp',
  './images/svc-laminator.webp',
  './images/svc-students.webp',
  './images/svc-gsites.webp',
  './images/svc-wordpress.webp',
  './images/svc-htmlcss.webp',
  './images/svc-eshop.webp',
  './images/svc-mpesa.webp',
  './images/svc-domain.webp',
  './images/svc-uiux.webp',
  './images/svc-letterhead.webp',
  './images/svc-infographic.webp',
  './images/svc-nca.webp',
  './images/svc-crb.webp',
  './images/svc-tsc.webp',
  './images/svc-ea.webp',
  './images/svc-canva.webp',
  './images/svc-passport.webp',
  './images/crs-hardware.webp',
  './images/crs-portal.webp',
  './images/crs-computer-packages.webp',
  './images/crs-web-design.webp',
  './images/crs-graphic-design.webp',
  './images/crs-cyber-safety.webp',
  './images/crs-programming.webp',
  './images/crs-digital-content.webp',
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js',
  'https://cdn.jsdelivr.net/npm/canvas-confetti@1.6.0/dist/confetti.browser.min.js',
  'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap'
];

function isAnalyticsOrWhatsApp(url) {
  return /(^|\.)wa\.me$/i.test(url.hostname)
    || /analytics|googletagmanager|google-analytics|goatcounter|\/collect(?:\/|$)/i.test(url.hostname + url.pathname);
}

function isCdnOrFont(url, request) {
  return request.destination === 'font'
    || url.hostname === 'fonts.googleapis.com'
    || url.hostname === 'fonts.gstatic.com'
    || url.hostname === 'cdnjs.cloudflare.com'
    || url.hostname === 'cdn.jsdelivr.net';
}

function isImage(request, url) {
  return request.destination === 'image' || /\.(?:avif|gif|ico|jpe?g|png|svg|webp)$/i.test(url.pathname);
}

async function storeResponse(cache, request, response) {
  if (response && (response.ok || response.type === 'opaque')) {
    try {
      await cache.put(request, response.clone());
    } catch (error) {
      console.warn('SITA-TECH could not cache a response:', request.url, error);
    }
  }
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await Promise.all(PRECACHE.map(async url => {
      try {
        const request = new Request(url, { cache: 'reload' });
        const response = await fetch(request);
        if (!response.ok && response.type !== 'opaque') {
          throw new Error(`Precache request failed with ${response.status}`);
        }
        await cache.put(request, response);
      } catch (error) {
        console.warn('SITA-TECH precache skipped:', url, error);
      }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith('sita-tech-') && key !== CACHE).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (isAnalyticsOrWhatsApp(url)) return;
  const cdnRequest = isCdnOrFont(url, request);
  if (url.origin !== self.location.origin && !cdnRequest) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);

    if (cdnRequest) {
      const cached = await cache.match(request);
      const refresh = fetch(request).then(async response => {
        await storeResponse(cache, request, response);
        return response;
      }).catch(() => null);
      if (cached) {
        event.waitUntil(refresh);
        return cached;
      }
      const response = await refresh;
      return response || new Response('CDN resource is unavailable offline.', { status: 503 });
    }

    if (isImage(request, url)) {
      const cached = await cache.match(request);
      if (cached) return cached;
      try {
        const response = await fetch(request);
        await storeResponse(cache, request, response);
        return response;
      } catch (error) {
        return new Response('Image is unavailable offline.', { status: 503 });
      }
    }

    const isPageOrJson = request.mode === 'navigate'
      || /\.(?:html|json)$/i.test(url.pathname)
      || url.pathname.endsWith('/');
    try {
      const response = await fetch(request);
      await storeResponse(cache, request, response);
      return response;
    } catch (error) {
      const cached = await cache.match(request) || (isPageOrJson ? await cache.match('./index.html') : null);
      return cached || new Response('This page is unavailable offline.', { status: 503 });
    }
  })());
});
