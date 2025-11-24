import { src, dest, series, parallel, watch } from 'gulp';
import { deleteAsync } from 'del';
import gulpElm from 'gulp-elm';
import uglify from 'gulp-uglify';
import rename from 'gulp-rename';
import { copy} from 'fs-extra';
import fs from 'fs';
import path from 'path';
import through2 from 'through2';
import log from 'fancy-log';
import { globby } from 'globby';
import pLimit from 'p-limit';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
import * as fsP from 'fs/promises';   // 👈 al inicio de tu archivo
import sharp from 'sharp';
import { exec } from 'child_process';

// Rutas de archivos
const paths = {
  elm: 'src/Main.elm',
  assets: 'assets/**/*.{png,jpg,jpeg,svg,webp}',
  html: 'index.html',
  robots: 'robots.txt',
  sitemap: 'sitemap.xml',
  output: 'build',
  h5pstandalone: 'h5p-standalone/**/*',
  highlight: 'highlight/**/*'
};

// Limpia la carpeta de salida
function clean() {
  return deleteAsync([paths.output]);
}

function elmTask() {
  return src(paths.elm)
    .pipe(gulpElm.bundle('main.js', { optimize: true }))
    .pipe(uglify({
      compress: {
        pure_funcs: [
          'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9',
          'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9'
        ],
        pure_getters: true,
        keep_fargs: false,
        unsafe_comps: true,
        unsafe: true
      },
      mangle: true
    }))
    .pipe(rename('main.min.js'))
    .pipe(dest(paths.output));
}


// TRATAMIENTO DE IMAGENES

// Config global de tamaños
const RESPONSIVE_WIDTHS = [200, 400, 800, 1200]; // ajusta a tu gusto
const CONCURRENCY = 4; // paralelismo controlado

async function responsiveImages() {
  const limit = pLimit(CONCURRENCY);

  const originalsAll = await globby(
    [
      'assets/productos/**/*.{png,PNG,webp,WEBP}',
    ],
    { dot: false }
  );

  // 👇 Solo archivos originales sin sufijo -<W>.* (evita C001-400.* como origen)
  const originals = originalsAll.filter(p => !isRenditionName(p));

  let created = 0;
  let skipped = 0;

  await Promise.all(
    originals.map((inPath) =>
      limit(async () => {
        try {
          const ext = path.extname(inPath).toLowerCase(); // .png | .webp
          const base = path.basename(inPath, ext);        // p.ej. "C001"
          const dir  = path.dirname(inPath);

          const meta = await sharp(inPath).metadata();
          const inputWidth = meta.width || 0;

          for (const W of RESPONSIVE_WIDTHS) {
            if (inputWidth && inputWidth < W) { skipped++; continue; }

            // WEBP target
            {
              const outWebp = path.join(dir, `${base}-${W}.webp`);
              const ok = await ensureRendition(inPath, outWebp, W, 'webp');
              if (ok) created++; else skipped++;
            }

            // PNG target solo si el origen es PNG
            if (ext === '.png') {
              const outPng = path.join(dir, `${base}-${W}.png`);
              const ok = await ensureRendition(inPath, outPng, W, 'png');
              if (ok) created++; else skipped++;
            }
          }
        } catch {
          /* silencioso */
        }
      })
    )
  );

  log(`🖼  responsiveImages → creados: ${created}, omitidos: ${skipped}`);
}


// Crea una versión si no existe o está vacía
async function ensureRendition(inPath, outPath, width, format) {
  try {
    const st = await fsP.stat(outPath);
    if (st.size > 0) {
      return false; // ya existe
    }
  } catch {
    // no existe, seguimos
  }

  try {
    let pipeline = sharp(inPath).resize({ width, withoutEnlargement: true });

    if (format === 'webp') {
      pipeline = pipeline.webp({ quality: 90 });
    } else if (format === 'png') {
      pipeline = pipeline.png({ compressionLevel: 9, adaptiveFiltering: true });
    } else {
      return false;
    }

    await pipeline.toFile(outPath);

    // validación mínima
    const st = await fsP.stat(outPath);
    if (!st || st.size === 0) {
      try { await fsP.unlink(outPath); } catch {}
      return false;
    }

    log(`✅  ${path.relative(process.cwd(), outPath)}`);
    return true;
  } catch {
    try { await fsP.unlink(outPath); } catch {}
    return false;
  }
}

function readDirRecursive(dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const list = fs.readdirSync(dir, { withFileTypes: true });
  list.forEach((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(readDirRecursive(full));
    } else {
      results.push(full);
    }
  });
  return results;
}

function findFileRecursive(startDir, filename) {
  if (!fs.existsSync(startDir)) return null;
  const files = readDirRecursive(startDir);
  for (let f of files) {
    if (path.basename(f).toLowerCase() === filename.toLowerCase()) {
      return f;
    }
  }
  return null;
}


function genCatalogoTask(cb) {
  try {
    const productosDir = path.join('assets', 'productos'); // ruta base
    const globalColorsDir = path.join(productosDir, 'colores'); // carpeta global de colores
    const outFile = path.join('assets', 'catalogo.json');

    fs.mkdirSync(path.dirname(outFile), { recursive: true });

    if (!fs.existsSync(productosDir)) {
      console.warn(`⚠️ No existe la carpeta ${productosDir}`);
      const empty = { baseUrl: "/assets/", colors: [], products: [] };
      fs.writeFileSync(outFile, JSON.stringify(empty, null, 2), 'utf8');
      cb();
      return;
    }

    const codeNameRegex = /^C\d{3,}\.(?:jpe?g|png|webp|avif|svg)$/i;
    const codeOnlyRegex = /^C\d{3,}$/i;

    // carpetas de producto (excluye la carpeta global 'colores')
    const productFolders = fs.readdirSync(productosDir, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => d.name)
      .filter(name => String(name).toLowerCase() !== 'colores')
      .sort();

    const allColorsSet = new Set();

    // 0) Primero: leer colores globales en assets/productos/colores/
    if (fs.existsSync(globalColorsDir)) {
      const globalFiles = readDirRecursive(globalColorsDir);
      globalFiles.forEach(f => {
        const base = path.basename(f);
        if (codeNameRegex.test(base)) {
          const code = base.split('.')[0].toUpperCase();
          if (codeOnlyRegex.test(code)) {
            allColorsSet.add(code);
          }
        }
      });
    }

    // 1) Ahora procesar cada producto (añadimos también colores encontrados en cada producto)
    const products = productFolders.map(folderName => {
      const folderPath = path.join(productosDir, folderName);

      // info.json (recursivo)
      const infoFile = findFileRecursive(folderPath, 'info.json');
      let info = {};
      if (infoFile) {
        try {
          const raw = fs.readFileSync(infoFile, 'utf8');
          const parsed = JSON.parse(raw);
          if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
            info = parsed;
          } else {
            console.warn(`⚠️ info.json en ${folderPath} no es un objeto válido`);
          }
        } catch (err) {
          console.warn(`⚠️ Error parseando info.json en ${folderPath}: ${err.message}`);
        }
      }

      // Colores del producto (carpeta del producto y su subcarpeta 'colores')
      const candidateDirs = [folderPath, path.join(folderPath, 'colores')].filter(d => fs.existsSync(d));
      let colorCodes = [];

      candidateDirs.forEach(d => {
        const allFiles = readDirRecursive(d);
        allFiles.forEach(f => {
          const base = path.basename(f);
          if (codeNameRegex.test(base)) {
            const code = base.split('.')[0].toUpperCase();
            if (codeOnlyRegex.test(code)) {
              colorCodes.push(code);
              allColorsSet.add(code); // también añadir al conjunto global
            }
          }
        });
      });

      const uniqueColors = Array.from(new Set(colorCodes)).sort((a, b) =>
        a.localeCompare(b, undefined, { sensitivity: 'base' })
      );

      const productObj = Object.assign({}, info, {
        codigo: folderName,
        colores: uniqueColors
      });

      return productObj;
    });

    const colorsArray = Array.from(allColorsSet).sort((a, b) =>
      a.localeCompare(b, undefined, { sensitivity: 'base' })
    );

    const manifest = {
      baseUrl: "/assets/",
      colors: colorsArray,
      products: products
    };

    fs.writeFileSync(outFile, JSON.stringify(manifest, null, 2), 'utf8');
    console.log(`✅ Catálogo generado: ${outFile} (${products.length} productos, ${colorsArray.length} colores)`);

    cb();
  } catch (err) {
    cb(err);
  }
}

const execFileAsync = promisify(execFile);

// Ajusta aquí si tienes más raíces posibles
const pngGlobs = [
  'assets/productos/**/*.{png,PNG}',
  'productos/**/*.{png,PNG}'
];

// Utils (ponlo arriba cerca de otros helpers)
const isRenditionName = (filePath) => {
  const bn = path.basename(filePath);          // p.ej. "C001-400.png"
  return /-\d+\.(?:png|webp)$/i.test(bn);      // true si termina en -<num>.(png|webp)
};


async function convertAll() {
  // antes: const files = await globby(pngGlobs, { dot: false });
  const filesAll = await globby(pngGlobs, { dot: false });
  const files = filesAll.filter(p => !isRenditionName(p)); // 👈 solo originales .png

  for (const inPath of files) {
    const outPath = inPath.replace(/\.(png|PNG)$/i, '.webp');

    try {
      const st = await fs.stat(outPath);
      if (st.size > 0) {
        log(`ℹ️  Ya existe: ${outPath}`);
        continue;
      }
    } catch {}

    try {
      await execFileAsync('cwebp', ['-quiet', '-q', '90', inPath, '-o', outPath]);
      const st = await fs.stat(outPath);
      if (!st || st.size === 0) throw new Error('El .webp generado está vacío');
      log(`✅  Generado: ${outPath}`);
    } catch {
      try { await fs.unlink(outPath); } catch {}
    }
  }
}




// Globs de entrada para colores en WEBP
const colorWebpGlobs = [
  'assets/productos/colores/**/*.webp',
];

// (Opcional) si alguna vez generas rendiciones tipo mycolor-400.webp, no las uses como origen
const isColorRenditionName = (filePath) => /-\d+\.webp$/i.test(path.basename(filePath));

async function convertColorWebpToPng() {
  const filesAll = await globby(colorWebpGlobs, { dot: false });

  // Evita rendiciones como origen (por si existen)
  const files = filesAll.filter((p) => !isColorRenditionName(p));

  let created = 0;
  let skipped = 0;

  for (const inPath of files) {
    const outPath = inPath.replace(/\.webp$/i, '.png');

    // Si ya existe el .png y pesa > 0, saltar
    try {
      const st = await fsP.stat(outPath);
      if (st.size > 0) {
        skipped++;
        continue;
      }
    } catch {
      // no existe; seguimos
    }

    try {
      await sharp(inPath)
        .png({ compressionLevel: 9, adaptiveFiltering: true })
        .toFile(outPath);

      const st = await fsP.stat(outPath);
      if (!st || st.size === 0) {
        try { await fsP.unlink(outPath); } catch {}
        skipped++;
        continue;
      }

      created++;
      log(`🎨  Color PNG creado: ${path.relative(process.cwd(), outPath)}`);
    } catch {
      // silencioso: si falla, intentamos limpiar y seguimos
      try { await fsP.unlink(outPath); } catch {}
      skipped++;
    }
  }

  log(`🎯 convertColorWebpToPng → creados: ${created}, omitidos: ${skipped}`);
}

async function cleanPng() {
  const files = await globby(pngGlobs, { dot: false });
  let removed = 0;

  for (const p of files) {
    const webp = p.replace(/\.(png|PNG)$/i, '.webp');
    try {
      const st = await fsP.stat(webp);    // existe y podemos ver su tamaño
      if (st.size > 0) {
        await fsP.unlink(p);              // borrar PNG correspondiente
        removed++;
        console.log(`🧹 Borrado PNG: ${p}`);
      }
    } catch {
      // silencioso: no hay .webp o no se puede acceder; no se borra nada
    }
  }

  if (!removed) {
    console.log('ℹ️  No había PNG para borrar (o no existe su .webp).');
  } else {
    console.log(`✅  PNG borrados: ${removed}`);
  }
}


// function webpackBuild(cb) {
//   exec('npx webpack --config webpack.config.js', (err, stdout, stderr) => {
//     console.log(stdout);
//     console.error(stderr);
//     cb(err);
//   });
// }

// Copia los assets
function assetsTask(cb) {
  copy('assets', 'build/assets')
    .then(() => cb())
    .catch(err => cb(err));
}

// Copia sitemap.xml
function highlightTask() {
  return src(paths.highlight)
    .pipe(dest(paths.output + '/assets'));
}


// Copia el HTML
function htmlTask() {
  return src(paths.html)
    .pipe(dest(paths.output));
}

// Copia robots.txt
function robotsTask() {
  return src(paths.robots)
    .pipe(dest(paths.output));
}

// Copia sitemap.xml
function sitemapTask() {
  return src(paths.sitemap)
    .pipe(dest(paths.output));
}

// Construye todo en paralelo (tras limpiar la carpeta)
const build = series(
  clean,
  parallel(elmTask, assetsTask, htmlTask)
);

const convertToWebP = series(convertAll);

// (Opcional) Tarea para vigilar archivos y recompilar al vuelo
function watchTask() {
  watch(paths.elm,  elmTask);
  watch(paths.assets, assetsTask);
  watch(paths.html, htmlTask);
  watch(paths.robots, robotsTask);
  watch(paths.sitemap, sitemapTask);
}

const dev = series(build, watchTask);

// const js = series(webpackBuild);

// Exporta las tareas
export { dev, watchTask as watch, build, build as default, convertToWebP as towebp, responsiveImages, convertColorWebpToPng, genCatalogoTask };