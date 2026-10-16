<?php

namespace App\Services\Geocoding;

use RuntimeException;

/** The address service is down, slow or busy; the caller shows a gentle retry message. */
class GeocodingUnavailable extends RuntimeException {}
