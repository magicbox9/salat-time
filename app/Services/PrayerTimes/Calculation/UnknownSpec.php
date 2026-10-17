<?php

namespace App\Services\PrayerTimes\Calculation;

use InvalidArgumentException;

/** A prayer spec with a family, rule or field the method does not define: fail closed, never guess. */
class UnknownSpec extends InvalidArgumentException {}
