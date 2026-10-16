<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Validation Language Lines (العربية)
    |--------------------------------------------------------------------------
    |
    | Translation of Laravel's default validation messages. Keep every key in
    | step with lang/en/validation.php (tests/Feature/I18n checks this).
    | Counts are phrased as "عدد حروف حقل … :max" so that the number never has
    | to agree with a counted noun.
    |
    */

    'accepted' => 'يجب قبول حقل :attribute.',
    'accepted_if' => 'يجب قبول حقل :attribute عندما تكون قيمة :other هي :value.',
    'active_url' => 'يجب أن يكون حقل :attribute رابطًا صحيحًا.',
    'after' => 'يجب أن يكون حقل :attribute تاريخًا بعد :date.',
    'after_or_equal' => 'يجب أن يكون حقل :attribute تاريخًا بعد :date أو مساويًا له.',
    'alpha' => 'يجب ألا يحتوي حقل :attribute إلا على حروف.',
    'alpha_dash' => 'يجب ألا يحتوي حقل :attribute إلا على حروف وأرقام وشرطات وشرطات سفلية.',
    'alpha_num' => 'يجب ألا يحتوي حقل :attribute إلا على حروف وأرقام.',
    'any_of' => 'حقل :attribute غير صالح.',
    'array' => 'يجب أن يكون حقل :attribute مصفوفة.',
    'array_keys' => 'يجب ألا يحتوي حقل :attribute إلا على المفاتيح التالية: :values.',
    'ascii' => 'يجب ألا يحتوي حقل :attribute إلا على حروف وأرقام ورموز أحادية البايت.',
    'base64' => 'يجب أن يكون حقل :attribute نصًا صحيحًا بترميز Base64.',
    'before' => 'يجب أن يكون حقل :attribute تاريخًا قبل :date.',
    'before_or_equal' => 'يجب أن يكون حقل :attribute تاريخًا قبل :date أو مساويًا له.',
    'between' => [
        'array' => 'يجب أن يكون عدد عناصر حقل :attribute بين :min و:max.',
        'file' => 'يجب أن يكون حجم ملف حقل :attribute بين :min و:max كيلوبايت.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute بين :min و:max.',
        'string' => 'يجب أن يكون عدد حروف حقل :attribute بين :min و:max.',
    ],
    'boolean' => 'يجب أن تكون قيمة حقل :attribute صحيحة أو خاطئة.',
    'can' => 'يحتوي حقل :attribute على قيمة غير مصرّح بها.',
    'confirmed' => 'تأكيد حقل :attribute غير مطابق.',
    'contains' => 'يفتقد حقل :attribute إلى قيمة مطلوبة.',
    'current_password' => 'كلمة المرور غير صحيحة.',
    'date' => 'يجب أن يكون حقل :attribute تاريخًا صحيحًا.',
    'date_equals' => 'يجب أن يكون حقل :attribute تاريخًا مساويًا لـ :date.',
    'date_format' => 'يجب أن يطابق حقل :attribute الصيغة :format.',
    'decimal' => 'يجب أن يكون عدد المنازل العشرية في حقل :attribute :decimal.',
    'declined' => 'يجب رفض حقل :attribute.',
    'declined_if' => 'يجب رفض حقل :attribute عندما تكون قيمة :other هي :value.',
    'different' => 'يجب أن يختلف حقل :attribute عن :other.',
    'digits' => 'يجب أن يكون عدد أرقام حقل :attribute :digits.',
    'digits_between' => 'يجب أن يكون عدد أرقام حقل :attribute بين :min و:max.',
    'dimensions' => 'أبعاد صورة حقل :attribute غير صالحة.',
    'distinct' => 'يحتوي حقل :attribute على قيمة مكررة.',
    'doesnt_contain' => 'يجب ألا يحتوي حقل :attribute على أيٍّ مما يلي: :values.',
    'doesnt_end_with' => 'يجب ألا ينتهي حقل :attribute بأيٍّ مما يلي: :values.',
    'doesnt_start_with' => 'يجب ألا يبدأ حقل :attribute بأيٍّ مما يلي: :values.',
    'email' => 'يجب أن يكون حقل :attribute عنوان بريد إلكتروني صحيحًا.',
    'encoding' => 'يجب أن يكون حقل :attribute بترميز :encoding.',
    'ends_with' => 'يجب أن ينتهي حقل :attribute بأحد ما يلي: :values.',
    'enum' => 'القيمة المحددة في حقل :attribute غير صالحة.',
    'exists' => 'القيمة المحددة في حقل :attribute غير صالحة.',
    'extensions' => 'يجب أن يكون لحقل :attribute أحد الامتدادات التالية: :values.',
    'file' => 'يجب أن يكون حقل :attribute ملفًا.',
    'filled' => 'يجب أن يحتوي حقل :attribute على قيمة.',
    'gt' => [
        'array' => 'يجب أن يكون عدد عناصر حقل :attribute أكثر من :value.',
        'file' => 'يجب أن يكون حجم ملف حقل :attribute أكبر من :value كيلوبايت.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute أكبر من :value.',
        'string' => 'يجب أن يكون عدد حروف حقل :attribute أكثر من :value.',
    ],
    'gte' => [
        'array' => 'يجب أن يكون عدد عناصر حقل :attribute :value أو أكثر.',
        'file' => 'يجب أن يكون حجم ملف حقل :attribute :value كيلوبايت أو أكثر.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute أكبر من :value أو مساوية لها.',
        'string' => 'يجب أن يكون عدد حروف حقل :attribute :value أو أكثر.',
    ],
    'hex_color' => 'يجب أن يكون حقل :attribute لونًا سداسي عشري صحيحًا.',
    'image' => 'يجب أن يكون حقل :attribute صورة.',
    'in' => 'القيمة المحددة في حقل :attribute غير صالحة.',
    'in_array' => 'يجب أن تكون قيمة حقل :attribute موجودة في :other.',
    'in_array_keys' => 'يجب أن يحتوي حقل :attribute على مفتاح واحد على الأقل من المفاتيح التالية: :values.',
    'integer' => 'يجب أن يكون حقل :attribute عددًا صحيحًا.',
    'ip' => 'يجب أن يكون حقل :attribute عنوان IP صحيحًا.',
    'ipv4' => 'يجب أن يكون حقل :attribute عنوان IPv4 صحيحًا.',
    'ipv6' => 'يجب أن يكون حقل :attribute عنوان IPv6 صحيحًا.',
    'json' => 'يجب أن يكون حقل :attribute نص JSON صحيحًا.',
    'list' => 'يجب أن يكون حقل :attribute قائمة.',
    'lowercase' => 'يجب أن يكون حقل :attribute بأحرف صغيرة.',
    'lt' => [
        'array' => 'يجب أن يكون عدد عناصر حقل :attribute أقل من :value.',
        'file' => 'يجب أن يكون حجم ملف حقل :attribute أقل من :value كيلوبايت.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute أقل من :value.',
        'string' => 'يجب أن يكون عدد حروف حقل :attribute أقل من :value.',
    ],
    'lte' => [
        'array' => 'يجب ألا يزيد عدد عناصر حقل :attribute على :value.',
        'file' => 'يجب ألا يزيد حجم ملف حقل :attribute على :value كيلوبايت.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute أقل من :value أو مساوية لها.',
        'string' => 'يجب ألا يزيد عدد حروف حقل :attribute على :value.',
    ],
    'mac_address' => 'يجب أن يكون حقل :attribute عنوان MAC صحيحًا.',
    'max' => [
        'array' => 'يجب ألا يزيد عدد عناصر حقل :attribute على :max.',
        'file' => 'يجب ألا يزيد حجم ملف حقل :attribute على :max كيلوبايت.',
        'numeric' => 'يجب ألا تزيد قيمة حقل :attribute على :max.',
        'string' => 'يجب ألا يزيد عدد حروف حقل :attribute على :max.',
    ],
    'max_digits' => 'يجب ألا يزيد عدد أرقام حقل :attribute على :max.',
    'mimes' => 'يجب أن يكون حقل :attribute ملفًا من نوع: :values.',
    'mimetypes' => 'يجب أن يكون حقل :attribute ملفًا من نوع: :values.',
    'min' => [
        'array' => 'يجب أن يكون عدد عناصر حقل :attribute :min على الأقل.',
        'file' => 'يجب أن يكون حجم ملف حقل :attribute :min كيلوبايت على الأقل.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute :min على الأقل.',
        'string' => 'يجب أن يكون عدد حروف حقل :attribute :min على الأقل.',
    ],
    'min_digits' => 'يجب أن يكون عدد أرقام حقل :attribute :min على الأقل.',
    'missing' => 'يجب ألا يكون حقل :attribute موجودًا.',
    'missing_if' => 'يجب ألا يكون حقل :attribute موجودًا عندما تكون قيمة :other هي :value.',
    'missing_unless' => 'يجب ألا يكون حقل :attribute موجودًا ما لم تكن قيمة :other هي :value.',
    'missing_with' => 'يجب ألا يكون حقل :attribute موجودًا عند وجود :values.',
    'missing_with_all' => 'يجب ألا يكون حقل :attribute موجودًا عند وجود :values.',
    'multiple_of' => 'يجب أن تكون قيمة حقل :attribute من مضاعفات :value.',
    'not_in' => 'القيمة المحددة في حقل :attribute غير صالحة.',
    'not_regex' => 'صيغة حقل :attribute غير صالحة.',
    'numeric' => 'يجب أن يكون حقل :attribute رقمًا.',
    'password' => [
        'letters' => 'يجب أن يحتوي حقل :attribute على حرف واحد على الأقل.',
        'mixed' => 'يجب أن يحتوي حقل :attribute على حرف كبير واحد وحرف صغير واحد على الأقل.',
        'numbers' => 'يجب أن يحتوي حقل :attribute على رقم واحد على الأقل.',
        'symbols' => 'يجب أن يحتوي حقل :attribute على رمز واحد على الأقل.',
        'uncompromised' => 'ظهرت قيمة حقل :attribute في تسريب للبيانات. يرجى اختيار قيمة أخرى.',
    ],
    'present' => 'يجب أن يكون حقل :attribute موجودًا.',
    'present_if' => 'يجب أن يكون حقل :attribute موجودًا عندما تكون قيمة :other هي :value.',
    'present_unless' => 'يجب أن يكون حقل :attribute موجودًا ما لم تكن قيمة :other هي :value.',
    'present_with' => 'يجب أن يكون حقل :attribute موجودًا عند وجود :values.',
    'present_with_all' => 'يجب أن يكون حقل :attribute موجودًا عند وجود :values.',
    'prohibited' => 'حقل :attribute محظور.',
    'prohibited_if' => 'حقل :attribute محظور عندما تكون قيمة :other هي :value.',
    'prohibited_if_accepted' => 'حقل :attribute محظور عند قبول :other.',
    'prohibited_if_declined' => 'حقل :attribute محظور عند رفض :other.',
    'prohibited_unless' => 'حقل :attribute محظور ما لم تكن قيمة :other ضمن :values.',
    'prohibits' => 'حقل :attribute يمنع وجود :other.',
    'regex' => 'صيغة حقل :attribute غير صالحة.',
    'required' => 'حقل :attribute مطلوب.',
    'required_array_keys' => 'يجب أن يحتوي حقل :attribute على مدخلات لـ: :values.',
    'required_if' => 'حقل :attribute مطلوب عندما تكون قيمة :other هي :value.',
    'required_if_accepted' => 'حقل :attribute مطلوب عند قبول :other.',
    'required_if_declined' => 'حقل :attribute مطلوب عند رفض :other.',
    'required_unless' => 'حقل :attribute مطلوب ما لم تكن قيمة :other ضمن :values.',
    'required_with' => 'حقل :attribute مطلوب عند وجود :values.',
    'required_with_all' => 'حقل :attribute مطلوب عند وجود :values.',
    'required_without' => 'حقل :attribute مطلوب عند عدم وجود :values.',
    'required_without_all' => 'حقل :attribute مطلوب عند عدم وجود أيٍّ من :values.',
    'same' => 'يجب أن يتطابق حقل :attribute مع :other.',
    'size' => [
        'array' => 'يجب أن يكون عدد عناصر حقل :attribute :size.',
        'file' => 'يجب أن يكون حجم ملف حقل :attribute :size كيلوبايت.',
        'numeric' => 'يجب أن تكون قيمة حقل :attribute :size.',
        'string' => 'يجب أن يكون عدد حروف حقل :attribute :size.',
    ],
    'starts_with' => 'يجب أن يبدأ حقل :attribute بأحد ما يلي: :values.',
    'string' => 'يجب أن يكون حقل :attribute نصًا.',
    'timezone' => 'يجب أن يكون حقل :attribute منطقة زمنية صحيحة.',
    'unique' => 'قيمة حقل :attribute مستخدمة من قبل.',
    'uploaded' => 'تعذّر رفع ملف حقل :attribute.',
    'uppercase' => 'يجب أن يكون حقل :attribute بأحرف كبيرة.',
    'url' => 'يجب أن يكون حقل :attribute رابطًا صحيحًا.',
    'ulid' => 'يجب أن يكون حقل :attribute معرّف ULID صحيحًا.',
    'uuid' => 'يجب أن يكون حقل :attribute معرّف UUID صحيحًا.',

    /*
    |--------------------------------------------------------------------------
    | Custom Validation Language Lines
    |--------------------------------------------------------------------------
    */

    'custom' => [
        'attribute-name' => [
            'rule-name' => 'custom-message',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Custom Validation Attributes
    |--------------------------------------------------------------------------
    |
    | Readable names for the form fields, e.g. «حقل البريد الإلكتروني مطلوب.»
    | instead of «حقل email مطلوب.»
    |
    */

    'attributes' => [
        'name' => 'الاسم',
        'email' => 'البريد الإلكتروني',
        'password' => 'كلمة المرور',
        'password_confirmation' => 'تأكيد كلمة المرور',
        'current_password' => 'كلمة المرور الحالية',
        'code' => 'الرمز',
        'recovery_code' => 'رمز الاسترداد',
        'token' => 'رمز التحقق',
        'remember' => 'تذكّرني',
        'locale' => 'اللغة',
        'title' => 'العنوان',
        'body' => 'المحتوى',
        'message' => 'الرسالة',
        'comment' => 'التعليق',
        'description' => 'الوصف',
        'phone' => 'الهاتف',
        'address' => 'العنوان البريدي',
        'city' => 'المدينة',
        'country' => 'البلد',
        'website' => 'الموقع الإلكتروني',
    ],

];
