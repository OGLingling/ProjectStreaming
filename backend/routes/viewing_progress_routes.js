const express = require('express');
const {
  getViewingProgress,
  upsertViewingProgress,
  completeViewingProgress,
} = require('../controllers/viewing_progress_controller');

const router = express.Router();

router.get('/', getViewingProgress);
router.post('/', upsertViewingProgress);
router.post('/complete', completeViewingProgress);

module.exports = router;
