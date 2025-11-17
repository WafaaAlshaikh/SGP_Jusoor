// controllers/institutionController.js
const Institution = require('../model/Institution');

exports.getInstitutions = async (req, res) => {
  try {
    const institutions = await Institution.findAll({
      attributes: [
        'institution_id',
        'name',
        'description',
        'location',
        'location_address',
        'city',
        'region',
        'website',
        'contact_info',
        'services_offered',
        'conditions_supported',
        'rating',
        'price_range',
        'capacity',
        'available_slots',
        'location_lat',
        'location_lng'
      ],
      order: [['name', 'ASC']]
    });
    
    // Format the response
    const formattedInstitutions = institutions.map(inst => ({
      institution_id: inst.institution_id,
      name: inst.name,
      description: inst.description,
      location: inst.location,
      location_address: inst.location_address,
      city: inst.city,
      region: inst.region,
      website: inst.website,
      contact_info: inst.contact_info,
      services_offered: inst.services_offered,
      conditions_supported: inst.conditions_supported,
      rating: parseFloat(inst.rating) || 0,
      price_range: inst.price_range,
      capacity: inst.capacity,
      available_slots: inst.available_slots,
      location_lat: inst.location_lat ? parseFloat(inst.location_lat) : null,
      location_lng: inst.location_lng ? parseFloat(inst.location_lng) : null
    }));
    
    res.status(200).json(formattedInstitutions);
  } catch (error) {
    console.error('Error fetching institutions:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};


