const Resource = require('../model/Resource');
const Diagnosis = require('../model/Diagnosis');
const Child = require('../model/Child');

exports.getParentResources = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({ where: { parent_id: parentId }});
    const diagnosisIds = children.map(c => c.diagnosis_id);

    const resources = await Resource.findAll({
      include: [{
        model: Diagnosis,
        where: { diagnosis_id: diagnosisIds },
        attributes: ['diagnosis_id', 'name'],
        through: { attributes: [] }
      }]
    });

    res.json(resources);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to fetch resources', error: error.message });
  }
};
