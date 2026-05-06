const VideoScraper = require('../services/scraper_service');

// ---------------------------------------------------------------------------
// Helpers del controlador
// ---------------------------------------------------------------------------

const describeParams = (params) =>
  Object.fromEntries(
    Object.entries(params || {}).map(([key, value]) => [
      key,
      { value, type: Array.isArray(value) ? 'array' : typeof value }
    ])
  );

const isPositiveIntegerLike = (value) => {
  if (value === undefined || value === null || value === '') return false;
  return Number.isInteger(Number(value)) && Number(value) > 0;
};

/** Strings que nunca deben considerarse valores válidos */
const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan']);

const firstValue = (...values) => {
  const value = values.find((item) => {
    if (item === undefined || item === null) return false;
    const s = String(item).toLowerCase().trim();
    return s !== '' && !INVALID_STRINGS.has(s);
  });
  return Array.isArray(value) ? value[0] : value;
};

// ---------------------------------------------------------------------------
// extractLink — handler principal
// ---------------------------------------------------------------------------

const extractLink = async (req, res) => {
  // --- Logging de entrada ---
  console.log('[extract] method:', req.method);
  console.log('[extract] originalUrl:', req.originalUrl);
  console.log('[extract] query:', describeParams(req.query));
  console.log('[extract] body:', describeParams(req.body));

  // --- Extracción de parámetros (soporta GET query y POST body) ---
  const url     = firstValue(req.query.url,    req.body?.url);
  const tmdbId  = firstValue(
    req.query.tmdbId, req.query.id, req.query.tmdb_id,
    req.body?.tmdbId, req.body?.id, req.body?.tmdb_id
  );
  const type    = firstValue(req.query.type,    req.body?.type);
  const season  = firstValue(req.query.season,  req.body?.season);
  const episode = firstValue(req.query.episode, req.body?.episode);

  const normalizedType = String(type || 'movie').toLowerCase().trim();
  const isTV = normalizedType.includes('tv') || normalizedType.includes('serie');
  const hasDirectUrl = url && /^https?:\/\//i.test(url);

  console.log('[extract] normalized:', describeParams({
    url, tmdbId, type: normalizedType, isTV, season, episode, hasDirectUrl
  }));

  // -----------------------------------------------------------------------
  // Validaciones por escenario
  // -----------------------------------------------------------------------

  // Escenario A: URL directa → se saltea las demás validaciones
  if (!hasDirectUrl) {

    // Debe existir un tmdbId si no hay URL directa
    if (!tmdbId) {
      return res.status(400).json({
        success: false,
        error:   'Falta el parámetro requerido: tmdbId o url',
        debug_info: {
          reason:  'missing_both_identifiers',
          detail:  'Se necesita una url (embed directo https://...) o un tmdbId numérico de TMDB.',
          hint:    'Verifica que el campo tmdb_id en tu DB no sea NULL.',
          received: {
            query: describeParams(req.query),
            body:  describeParams(req.body),
            acceptedIdNames: ['tmdbId', 'id', 'tmdb_id']
          }
        }
      });
    }

    // tmdbId debe ser un entero positivo
    if (!isPositiveIntegerLike(tmdbId)) {
      return res.status(400).json({
        success: false,
        error:   'Parámetro inválido: tmdbId debe ser un entero positivo',
        debug_info: {
          reason:   'invalid_tmdb_id_format',
          detail:   `Se recibió tmdbId="${tmdbId}" (${typeof tmdbId}).`,
          hint:     'El tmdbId es el ID numérico de TMDB (ej: 550, 1396). IMDB IDs (tt...) no son válidos.',
          received: describeParams({ tmdbId })
        }
      });
    }

    // Para TV, season y episode son obligatorios
    if (isTV && !isPositiveIntegerLike(season)) {
      return res.status(400).json({
        success: false,
        error:   'Parámetro inválido o faltante: season requerido para contenido tv',
        debug_info: {
          reason:  'missing_season',
          detail:  `type="${normalizedType}" requiere season ≥ 1.`,
          hint:    'Envía season=1 (o el número de temporada) junto con el tmdbId.',
          received: describeParams({ type, season })
        }
      });
    }

    if (isTV && !isPositiveIntegerLike(episode)) {
      return res.status(400).json({
        success: false,
        error:   'Parámetro inválido o faltante: episode requerido para contenido tv',
        debug_info: {
          reason:  'missing_episode',
          detail:  `type="${normalizedType}" requiere episode ≥ 1.`,
          hint:    'Envía episode=1 (o el número de episodio) junto con tmdbId y season.',
          received: describeParams({ type, episode })
        }
      });
    }
  }

  // -----------------------------------------------------------------------
  // Llamada al servicio
  // -----------------------------------------------------------------------

  try {
    const result = await VideoScraper.extractStreamUrl({
      url, tmdbId, type: normalizedType, season, episode
    });

    if (!result || !Array.isArray(result.candidates) || result.candidates.length === 0) {
      return res.status(404).json({
        success: false,
        error:   'No hay candidatos disponibles para este recurso',
        debug_info: result?.debug_info ?? {
          status: 'error',
          reason: 'empty_candidates',
          detail: 'El servicio no generó URLs de candidatos para el input recibido.'
        }
      });
    }

    return res.status(200).json({
      success: true,
      data:    result
    });

  } catch (error) {
    console.error('[extract] Error crítico:', error.message);
    return res.status(500).json({
      success: false,
      error:   error.message,
      debug_info: {
        status: 'error',
        reason: 'internal_server_error',
        detail: error.message
      }
    });
  }
};

module.exports = { extractLink };
