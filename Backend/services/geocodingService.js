// services/geocodingService.js
const axios = require('axios');
const { googleMaps } = require('../config/apis');

class GeocodingService {
  static async geocodeAddress(address) {
    try {
      console.log('📍 جاري تحويل العنوان إلى إحداثيات:', address);
      
      const response = await axios.get(googleMaps.geocodingUrl, {
        params: {
          address: address,
          key: googleMaps.apiKey
        }
      });

      if (response.data.status === 'OK' && response.data.results.length > 0) {
        const location = response.data.results[0].geometry.location;
        console.log('✅ تم تحويل العنوان بنجاح:', location);
        
        return {
          lat: location.lat,
          lng: location.lng,
          formatted_address: response.data.results[0].formatted_address
        };
      } else {
        console.warn('⚠️ لم يتم العثور على إحداثيات للعنوان:', address, response.data.status);
        return null;
      }
    } catch (error) {
      console.error('❌ خطأ في تحويل العنوان:', error.message);
      return null;
    }
  }

  static async geocodeCity(cityName) {
    try {
      // تحويل اسم المدينة فقط
      const response = await axios.get(googleMaps.geocodingUrl, {
        params: {
          address: cityName + ', Saudi Arabia',
          key: googleMaps.apiKey
        }
      });

      if (response.data.status === 'OK' && response.data.results.length > 0) {
        const location = response.data.results[0].geometry.location;
        return {
          lat: location.lat,
          lng: location.lng
        };
      }
      return null;
    } catch (error) {
      console.error('Error geocoding city:', error);
      return null;
    }
  }
}

module.exports = GeocodingService;