const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const managerAuthMiddleware = require('../middleware/managerAuth');

const equipmentManagementController = require('../controllers/equipmentManagementController');

router.post('/needs', authMiddleware, equipmentManagementController.createNeedBySpecialist);

router.post('/ai/needs/suggest', authMiddleware, equipmentManagementController.suggestNeedsFromEvaluationForSpecialist);
router.post('/ai/needs/confirm', authMiddleware, equipmentManagementController.confirmAISuggestedNeeds);

router.get('/specialist/needs', authMiddleware, equipmentManagementController.getChildNeedsForSpecialist);

router.get('/manager/inventory', authMiddleware, managerAuthMiddleware, equipmentManagementController.getManagerInventory);
router.get('/manager/needs', authMiddleware, managerAuthMiddleware, equipmentManagementController.getManagerNeeds);
router.get('/manager/campaigns', authMiddleware, managerAuthMiddleware, equipmentManagementController.getManagerEquipmentCampaigns);
router.put('/manager/campaigns/:campaign_id', authMiddleware, managerAuthMiddleware, equipmentManagementController.updateManagerEquipmentCampaign);
router.post('/manager/allocate/child', authMiddleware, managerAuthMiddleware, equipmentManagementController.allocateManuallyToChild);
router.post('/manager/inventory/internal', authMiddleware, managerAuthMiddleware, equipmentManagementController.setInventoryInternalUse);
router.get('/manager/inventory/:inventory_item_id/history', authMiddleware, managerAuthMiddleware, equipmentManagementController.getInventoryHistory);

router.get('/parent/allocations', authMiddleware, equipmentManagementController.getParentAllocations);
router.post('/parent/allocations/:allocation_id/confirm-receipt', authMiddleware, equipmentManagementController.parentConfirmReceipt);

module.exports = router;
