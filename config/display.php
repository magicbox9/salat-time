<?php

/*
 * The full-screen prayer display (mosque TVs and personal screens).
 *
 * `defaults` is the single list of known settings: a mosque's choices
 * (mosque_display_settings.settings) and a person's choices
 * (users.preferences.display) are merged over it, and any other key is
 * dropped (App\Services\Display\DisplaySettings).
 */
return [

    'themes' => ['classic', 'night_sky', 'arabesque', 'minimal'],

    'orientations' => ['auto', 'landscape', 'portrait'],

    'languages' => ['ar', 'fr', 'en'],

    'rotation_sources' => ['messages', 'quran', 'adhkar', 'posts', 'campaigns'],

    'adhan_modes' => ['sound', 'visual', 'off'],

    'clocks' => ['24h', '12h'],

    'defaults' => [
        'theme' => 'classic',
        'orientation' => 'auto',
        'accent_color' => null,
        // First = main language of the screen, second = smaller line under it.
        'languages' => ['ar', 'fr'],
        'clock' => '24h',
        'show_seconds' => true,
        'show_iqama' => true,
        'show_shuruq' => true,
        'show_jumua' => true,
        'show_hijri' => true,
        'hijri_adjust' => 0,
        'approaching_minutes' => 10,
        'adhan_minutes' => 4,
        'iqama_seconds' => 60,
        'blackout_minutes' => ['fajr' => 12, 'dhuhr' => 12, 'asr' => 10, 'maghrib' => 8, 'isha' => 12, 'jumua' => 40],
        'after_adhkar' => true,
        'after_adhkar_minutes' => 5,
        'rotation' => ['messages', 'quran', 'adhkar', 'posts', 'campaigns'],
        'rotation_seconds' => 20,
        'adhan_mode' => 'visual',
        // The official Salat Time adhan (see 'adhan.official' below).
        'adhan_id' => 'official',
        'fajr_adhan_id' => 'official_fajr',
        'volume' => 80,
        // Personal screens only (a mosque screen is muted from its own controls).
        'muted' => false,
        'night_dim' => false,
        'night_from' => '23:00',
        'night_to' => '05:00',
    ],

    /** Allowed ranges of the numeric settings (inclusive). */
    'ranges' => [
        'hijri_adjust' => [-2, 2],
        'approaching_minutes' => [0, 30],
        'adhan_minutes' => [1, 10],
        'iqama_seconds' => [10, 180],
        'blackout_minutes' => [0, 90],
        'after_adhkar_minutes' => [1, 15],
        'rotation_seconds' => [8, 120],
        'volume' => [0, 100],
    ],

    /** Seconds display.json is cached on the server (and in the browser). */
    'cache_seconds' => 60,

    'max_messages' => 30,

    'max_background_kb' => 5 * 1024,

    'max_adhan_kb' => 10 * 1024,

    /*
     * Qur'an verses the screen rotates through, as Hafs keys ("surah:ayah" or
     * "surah:first-last"). Only keys: the Arabic comes from the verified
     * KFGQPC corpus and the meanings from the QuranEnc snapshots, unchanged.
     * Chosen so that neither translation carries a footnote marker.
     */
    'verses' => [
        '2:45', '2:110', '2:277', '3:191', '4:103', '7:205', '13:28', '14:40',
        '20:14', '22:77', '23:1-2', '33:41-42', '40:60', '51:56', '98:5', '103:1-3',
    ],

    /** Morning / evening adhkar longer than this (characters) are left out of the rotation. */
    'adhkar_max_length' => 320,

    /*
     * Adhan recordings fetched by `php artisan adhan:fetch` into the public
     * disk (adhan/), the same 14 files as the Mac app's build.sh. Rights must
     * be cleared with the publisher before a public launch.
     */
    'adhan' => [
        'folder' => 'adhan',
        'base_url' => 'https://media.assabile.com/assabile/adhan_3435370',
        'referer' => 'https://www.assabile.com/',
        'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
        'timeout' => 45,
        'min_bytes' => 20000,
        /*
         * The official Salat Time adhan, the default in every Salat Time app:
         * Mansour Al-Zahrani. Fajr plays the whole recording; the other
         * prayers play it without the Fajr-only passage (2:03.866–2:29.440,
         * "as-salatu khayrun min an-nawm"). `adhan:fetch` renders both files
         * from adhan_zahrani.mp3 (ffmpeg). Keep these cut points identical in
         * the Mac and Windows apps.
         */
        'official' => [
            'source' => 'adhan_zahrani.mp3',
            'regular' => ['id' => 'official', 'file' => 'adhan_official.mp3', 'name' => 'Salat Time — Mansour Al-Zahrani',
                'keep' => [[0.0, 123.866], [149.440, null]]],
            'fajr' => ['id' => 'official_fajr', 'file' => 'adhan_official_fajr.mp3', 'name' => 'Salat Time — Mansour Al-Zahrani (Fajr)',
                'keep' => [[0.0, null]]],
        ],
        'recordings' => [
            ['id' => 'makkah_mulla', 'file' => 'adhan_makkah_mulla.mp3', 'hash' => '166d1f7c435a', 'name' => 'Makkah — Sheikh Ali Ibn Ahmed Mala'],
            ['id' => 'madinah', 'file' => 'adhan_madinah.mp3', 'hash' => 'b30ca9a3e115', 'name' => 'Madinah — Masjid an-Nabawi'],
            ['id' => 'aqsa', 'file' => 'adhan_aqsa.mp3', 'hash' => '768559b47c2e', 'name' => 'Al-Aqsa — Naji Qazzaz'],
            ['id' => 'dossari', 'file' => 'adhan_dossari.mp3', 'hash' => 'f5370aa1a7e2', 'name' => 'Yasser Al-Dossari'],
            ['id' => 'zahrani', 'file' => 'adhan_zahrani.mp3', 'hash' => 'cb51ad2c0c7e', 'name' => 'Mansour Al-Zahrani'],
            ['id' => 'obaid', 'file' => 'adhan_obaid.mp3', 'hash' => '45299e6a8a68', 'name' => 'Nasser Al-Obaid'],
            ['id' => 'majali', 'file' => 'adhan_majali.mp3', 'hash' => '495dea4f4ea5', 'name' => 'Hamza Al-Majali'],
            ['id' => 'yamani', 'file' => 'adhan_yamani.mp3', 'hash' => '091fa01b11f4', 'name' => "Wadi' Hammadi Al-Yamani"],
            ['id' => 'kabbara', 'file' => 'adhan_kabbara.mp3', 'hash' => '8bd66fa73ff9', 'name' => 'Mohammed Salahuddin Kabbara'],
            ['id' => 'kourdi', 'file' => 'adhan_kourdi.mp3', 'hash' => '8c052a5edec1', 'name' => 'Ahmed Al-Kourdi'],
            ['id' => 'feqy', 'file' => 'adhan_feqy.mp3', 'hash' => '83e17f5db5a7', 'name' => 'Mohamed Abdel-Basset Al-Feqy'],
            ['id' => 'damradach', 'file' => 'adhan_damradach.mp3', 'hash' => 'cd17c7200df5', 'name' => 'Mohammed Al-Damradach'],
            ['id' => 'kreiny', 'file' => 'adhan_kreiny.mp3', 'hash' => '229d65e40fdf', 'name' => 'Mohammed Al-Kreiny Al-Malouki'],
            ['id' => 'jazairi', 'file' => 'adhan_jazairi.mp3', 'hash' => '0bf83c80b583', 'name' => 'Rabih Ibn Darah Al-Jazairi'],
        ],
    ],
];
