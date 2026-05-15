require('dotenv').config();
const axios = require('axios');

async function debug() {
  const token = (process.env.TMDB_API_TOKEN || '').trim();
  const url = 'https://api.themoviedatabase.org/3/movie/157336?language=es-ES';
  
  console.log('--- DEBUG INICIADO ---');
  console.log('URL:', url);
  console.log('Token (primeros 20 caracteres):', token.substring(0, 20));

  try {
    const res = await axios.get(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0'
      }
    });
    console.log('Status:', res.status);
    console.log('Content-Type:', res.headers['content-type']);
    console.log('Data:', res.data);
  } catch (err) {
    console.log('ERROR STATUS:', err.response?.status);
    console.log('ERROR DATA:', err.response?.data);
  }
}

debug();
