using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace SalatTime.Core;

/// <summary>
/// Reads mosque schedules and search results from mawaqit.net, the same way the
/// Mac app does: the mosque page embeds a <c>confData</c> object with the full
/// year, and mosque search goes through the public search endpoint.
/// When a page can only be read by running its scripts, <see cref="WebFallback"/>
/// (WebView2 on Windows) runs the Mac app's extraction script instead.
/// </summary>
public static class MawaqitClient
{
    static readonly HttpClient Http = CreateClient();

    /// <summary>Optional script runner used when plain HTTP parsing fails (set by the Windows platform layer).</summary>
    public static IWebPageRunner? WebFallback { get; set; }

    static HttpClient CreateClient()
    {
        var handler = new HttpClientHandler { AutomaticDecompression = DecompressionMethods.All };
        var c = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(20) };
        c.DefaultRequestHeaders.UserAgent.ParseAdd(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 SalatTime/1.0");
        c.DefaultRequestHeaders.AcceptLanguage.ParseAdd("fr,en;q=0.8");
        return c;
    }

    // ------------------------------------------------------------------ mosque page

    public static async Task<MosqueInfo?> FetchMosqueAsync(string url, CancellationToken ct = default)
    {
        var target = MosqueUrls.Normalize(url);
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, target);
            req.Headers.Accept.ParseAdd("text/html,application/xhtml+xml");
            using var resp = await Http.SendAsync(req, ct).ConfigureAwait(false);
            if (resp.IsSuccessStatusCode)
            {
                var html = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
                var finalUrl = resp.RequestMessage?.RequestUri?.ToString() ?? target;
                if (ExtractConfData(html) is string json && ParseConfData(json, Clock.Now(), finalUrl) is { HasTimes: true } info)
                    return info;
            }
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException) { }

        if (WebFallback is not null)
        {
            var result = await WebFallback.EvaluateAsync(target, Scripts.ExtractMosque, TimeSpan.Zero, ct).ConfigureAwait(false);
            if (result.Json is string raw && ParseConfData(raw, Clock.Now(), result.FinalUrl ?? target) is { HasTimes: true } info)
                return info;
        }
        return null;
    }

    /// <summary>Find <c>confData = {...}</c> in the page and return the object literal.</summary>
    public static string? ExtractConfData(string html)
    {
        var m = Regex.Match(html, @"confData\s*=\s*\{");
        while (m.Success)
        {
            var start = m.Index + m.Length - 1;
            if (BalancedObject(html, start) is string obj) return obj;
            m = m.NextMatch();
        }
        return null;
    }

    static string? BalancedObject(string s, int start)
    {
        int depth = 0;
        char quote = '\0';
        for (int i = start; i < s.Length; i++)
        {
            var c = s[i];
            if (quote != '\0')
            {
                if (c == '\\') { i++; continue; }
                if (c == quote) quote = '\0';
                continue;
            }
            switch (c)
            {
                case '"': case '\'': quote = c; break;
                case '{': case '[': depth++; break;
                case '}': case ']':
                    depth--;
                    if (depth == 0) return s.Substring(start, i - start + 1);
                    break;
            }
        }
        return null;
    }

    static readonly JsonDocumentOptions DocOptions = new() { AllowTrailingCommas = true, CommentHandling = JsonCommentHandling.Skip };

    /// <summary>Turn the raw confData JSON into a <see cref="MosqueInfo"/> (port of the Mac extraction script).</summary>
    public static MosqueInfo? ParseConfData(string json, DateTime today, string sourceUrl)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(json, DocOptions); }
        catch (JsonException) { return null; }
        using (doc)
        {
            var d = doc.RootElement;
            if (d.ValueKind != JsonValueKind.Object) return null;
            var info = new MosqueInfo
            {
                Name = Str(d, "name") is { Length: > 0 } n ? n : Str(d, "label"),
                Localisation = Str(d, "localisation") is { Length: > 0 } l ? l : Str(d, "association"),
                Phone = Str(d, "phone"),
                Site = Str(d, "site"),
                Date = today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                SourceUrl = sourceUrl,
                Latitude = Num(d, "latitude"),
                Longitude = Num(d, "longitude"),
                HijriAdjustment = Num(d, "hijriAdjustment") is double h ? (int)h : null,
                ImsakMinutes = Num(d, "imsakNbMinBeforeFajr") is double im ? (int)im : null,
            };

            info.Calendar = d.TryGetProperty("calendar", out var cal) ? NormalizeCalendar(cal, NormTime) : null;
            info.IqamaCalendar = d.TryGetProperty("iqamaCalendar", out var iqCal) ? NormalizeCalendar(iqCal, MapIqama) : null;

            // 1) Today's row from the calendar (what the mosque published).
            if (info.Calendar is not null && info.CalendarRow(today) is { } row)
            {
                info.Shuruq = row[1];
                info.Times = new List<string> { row[0], row[2], row[3], row[4], row[5] };
            }
            // 2) Fallback: d.times.
            if (info.Times.Count < 5 && d.TryGetProperty("times", out var times) && times.ValueKind == JsonValueKind.Array)
            {
                var t = times.EnumerateArray().Select(NormTime).ToList();
                if (t.Count == 6) { if (info.Shuruq.Length == 0) info.Shuruq = t[1]; info.Times = new() { t[0], t[2], t[3], t[4], t[5] }; }
                else info.Times = t.Take(5).ToList();
            }
            // 3) Explicit shuruq.
            if (info.Shuruq.Length == 0 && d.TryGetProperty("shuruq", out var sh)) info.Shuruq = NormTime(sh);

            // Iqama: array, object keyed by prayer, or today's iqama calendar row.
            JsonElement rawIq = default;
            var hasIq = d.TryGetProperty("iqama", out rawIq) || d.TryGetProperty("iqamas", out rawIq);
            if (hasIq && rawIq.ValueKind == JsonValueKind.Array)
                info.Iqama = rawIq.EnumerateArray().Take(5).Select(MapIqama).ToList();
            else if (hasIq && rawIq.ValueKind == JsonValueKind.Object)
                info.Iqama = new[] { "fajr", "dhuhr", "asr", "maghrib", "isha" }
                    .Select(k => rawIq.TryGetProperty(k, out var v) || rawIq.TryGetProperty(char.ToUpper(k[0]) + k[1..], out v) ? MapIqama(v) : "")
                    .ToList();
            if ((info.Iqama.Count == 0 || info.Iqama.All(string.IsNullOrEmpty)) && info.IqamaRow(today) is { } iqRow)
                info.Iqama = iqRow.Take(5).ToList();

            // Jumua: a single time, several services, or jumuaTime.
            if (d.TryGetProperty("jumua", out var j))
            {
                if (j.ValueKind == JsonValueKind.String) { info.Jumua = NormTime(j); if (info.Jumua.Length > 0) info.JumuaTimes = new() { info.Jumua }; }
                else if (j.ValueKind == JsonValueKind.Array)
                {
                    info.JumuaTimes = j.EnumerateArray().Select(NormTime).Where(s => s.Length > 0).ToList();
                    info.Jumua = info.JumuaTimes.FirstOrDefault() ?? "";
                }
            }
            if (info.Jumua.Length == 0 && d.TryGetProperty("jumuaTime", out var jt))
            {
                info.Jumua = NormTime(jt);
                if (info.Jumua.Length > 0) info.JumuaTimes = new() { info.Jumua };
            }
            if (d.TryGetProperty("sunset", out var ss) || d.TryGetProperty("sunsetTime", out ss))
                info.Sunset = NormTime(ss) is { Length: > 0 } s ? s : null;

            return info;
        }
    }

    static string Str(JsonElement d, string key) =>
        d.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";

    static double? Num(JsonElement d, string key)
    {
        if (!d.TryGetProperty(key, out var v)) return null;
        if (v.ValueKind == JsonValueKind.Number && v.TryGetDouble(out var n)) return n;
        if (v.ValueKind == JsonValueKind.String &&
            double.TryParse(v.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var p)) return p;
        return null;
    }

    static string NormTime(JsonElement v)
    {
        switch (v.ValueKind)
        {
            case JsonValueKind.Number:
                var n = (int)Math.Floor(v.GetDouble());
                return $"{n / 60:00}:{n % 60:00}";
            case JsonValueKind.String:
                return v.GetString() ?? "";
            default:
                return "";
        }
    }

    static string MapIqama(JsonElement v)
    {
        switch (v.ValueKind)
        {
            case JsonValueKind.Number:
                return "+" + v.GetDouble().ToString(CultureInfo.InvariantCulture);
            case JsonValueKind.String:
                var s = (v.GetString() ?? "").Trim();
                if (s.Length == 0) return "";
                if (Regex.IsMatch(s, @"^[+-]?\d+$")) return s.StartsWith('-') ? s : "+" + s.TrimStart('+');
                return s;
            default:
                return "";
        }
    }

    static List<List<List<string>>>? NormalizeCalendar(JsonElement cal, Func<JsonElement, string> mapper)
    {
        var months = new List<JsonElement?>();
        if (cal.ValueKind == JsonValueKind.Array)
        {
            var arr = cal.EnumerateArray().ToList();
            months.AddRange(arr.Skip(arr.Count >= 13 ? 1 : 0).Select(e => (JsonElement?)e));
        }
        else if (cal.ValueKind == JsonValueKind.Object)
        {
            for (int mi = 1; mi <= 12; mi++)
                months.Add(cal.TryGetProperty(mi.ToString(CultureInfo.InvariantCulture), out var e) ? e : null);
        }
        else return null;
        if (months.Count < 12) return null;

        var result = new List<List<List<string>>>();
        for (int m = 0; m < 12; m++)
        {
            var days = new List<JsonElement>();
            if (months[m] is JsonElement entry)
            {
                if (entry.ValueKind == JsonValueKind.Array)
                {
                    var arr = entry.EnumerateArray().ToList();
                    days.AddRange(arr.Skip(arr.Count >= 32 ? 1 : 0));
                }
                else if (entry.ValueKind == JsonValueKind.Object)
                {
                    for (int di = 1; di <= 31; di++)
                    {
                        if (!entry.TryGetProperty(di.ToString(CultureInfo.InvariantCulture), out var row)) break;
                        days.Add(row);
                    }
                }
            }
            result.Add(days.Select(row => row.ValueKind == JsonValueKind.Array
                ? row.EnumerateArray().Select(mapper).ToList()
                : new List<string>()).ToList());
        }
        return result;
    }

    // ------------------------------------------------------------------ search

    public static async Task<List<MosqueRef>> SearchAsync(string word, CancellationToken ct = default)
    {
        var q = word.Trim();
        if (q.Length == 0) return new();
        var enc = Uri.EscapeDataString(q);
        var refs = await ApiAsync($"https://mawaqit.net/api/2.0/mosque/search?word={enc}&page=1", ct).ConfigureAwait(false);
        if (refs.Count > 0 || ct.IsCancellationRequested) return refs;

        // Fallback 1: the public search page, when it lists results in its HTML.
        refs = await ScrapeSearchPageAsync($"https://mawaqit.net/fr/search?search={enc}", ct).ConfigureAwait(false);
        if (refs.Count > 0 || ct.IsCancellationRequested) return refs;

        // Fallback 2: let WebView2 render the page and read its links (Mac script).
        if (WebFallback is not null)
        {
            var result = await WebFallback.EvaluateAsync($"https://mawaqit.net/fr/search?search={enc}",
                Scripts.ExtractSearchLinks, TimeSpan.FromSeconds(2.2), ct).ConfigureAwait(false);
            if (result.Json is string json) refs = ParseLinkResults(json);
        }
        return refs;
    }

    public static Task<List<MosqueRef>> NearbyAsync(double lat, double lon, CancellationToken ct = default) =>
        ApiAsync(string.Create(CultureInfo.InvariantCulture, $"https://mawaqit.net/api/2.0/mosque/geolocation/{lat}/{lon}?page=1"), ct);

    static async Task<List<MosqueRef>> ApiAsync(string url, CancellationToken ct)
    {
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            using var resp = await Http.SendAsync(req, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) return new();
            var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (!body.TrimStart().StartsWith('[') && !body.TrimStart().StartsWith('{')) return new();
            return ParseApiResponse(body);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException or JsonException)
        {
            return new();
        }
    }

    public static List<MosqueRef> ParseApiResponse(string body)
    {
        using var doc = JsonDocument.Parse(body, DocOptions);
        var root = doc.RootElement;
        IEnumerable<JsonElement> items = Array.Empty<JsonElement>();
        if (root.ValueKind == JsonValueKind.Array) items = root.EnumerateArray().ToList();
        else if (root.ValueKind == JsonValueKind.Object)
        {
            foreach (var key in new[] { "data", "results", "items", "mosques" })
                if (root.TryGetProperty(key, out var a) && a.ValueKind == JsonValueKind.Array) { items = a.EnumerateArray().ToList(); break; }
        }

        var refs = new List<MosqueRef>();
        var seen = new HashSet<string>();
        foreach (var it in items)
        {
            if (it.ValueKind != JsonValueKind.Object) continue;
            var name = Str(it, "label") is { Length: > 0 } l ? l : Str(it, "name");
            var city = Str(it, "city");
            if (city.Length == 0 && it.TryGetProperty("city", out var ci) && ci.ValueKind == JsonValueKind.Object) city = Str(ci, "name");
            if (city.Length == 0) city = Str(it, "locality");
            var address = new[] { "localisation", "address", "street" }.Select(k => Str(it, k)).FirstOrDefault(s => s.Length > 0) ?? "";
            if (city.Length == 0 && address.Length > 0) city = CityFromAddress(address) ?? "";
            var url = Str(it, "url");
            if (url.Length == 0 && Str(it, "slug") is { Length: > 0 } slug) url = $"https://mawaqit.net/fr/m/{slug}";
            if (url.Length == 0 && Str(it, "uuid") is { Length: > 0 } uuid) url = $"https://mawaqit.net/fr/id/{uuid}";
            if (name.Length == 0 || url.Length == 0) continue;
            if (!seen.Add(MosqueUrls.Normalize(url))) continue;
            refs.Add(new MosqueRef
            {
                Name = name, City = city, Url = url, Address = address.Length > 0 ? address : null,
                Lat = Num(it, "latitude") ?? Num(it, "lat"),
                Lon = Num(it, "longitude") ?? Num(it, "lng") ?? Num(it, "lon"),
            });
        }
        return refs;
    }

    /// <summary>Best-effort city name from an address line (port of the Mac helper).</summary>
    public static string? CityFromAddress(string raw)
    {
        var s = raw.Trim();
        if (s.Length == 0) return null;
        var m = Regex.Match(s, @"\b\d{4,6}\s+([^\d,]+)$");
        if (m.Success && m.Groups[1].Value.Trim().Length >= 2) return Title(m.Groups[1].Value.Trim());
        var comma = s.LastIndexOf(',');
        if (comma >= 0)
        {
            var tail = s[(comma + 1)..].Trim();
            if (tail.Length >= 2 && !tail.Any(char.IsDigit)) return Title(tail);
        }
        var last = s.Split(' ', '\t').LastOrDefault() ?? "";
        if (last.Length >= 3 && last == last.ToUpperInvariant() && last != last.ToLowerInvariant()) return Title(last);
        return null;
    }

    static string Title(string s) => CultureInfo.InvariantCulture.TextInfo.ToTitleCase(s.ToLowerInvariant());

    static async Task<List<MosqueRef>> ScrapeSearchPageAsync(string url, CancellationToken ct)
    {
        try
        {
            var html = await Http.GetStringAsync(url, ct).ConfigureAwait(false);
            var refs = new List<MosqueRef>();
            var seen = new HashSet<string>();
            foreach (Match m in Regex.Matches(html, @"<a[^>]+href=""(?<href>[^""]*/m/[^""]+)""[^>]*>(?<text>.*?)</a>", RegexOptions.Singleline))
            {
                var href = WebUtility.HtmlDecode(m.Groups["href"].Value);
                if (href.StartsWith('/')) href = "https://mawaqit.net" + href;
                if (!href.Contains("mawaqit.net") || !seen.Add(MosqueUrls.Normalize(href))) continue;
                var text = WebUtility.HtmlDecode(Regex.Replace(m.Groups["text"].Value, "<.*?>", " ")).Trim();
                text = Regex.Replace(text, @"\s+", " ");
                if (text.Length == 0) text = href.Split("/m/").Last().Replace('-', ' ');
                refs.Add(new MosqueRef { Name = text.Length > 200 ? text[..200] : text, Url = href });
            }
            return refs;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException) { return new(); }
    }

    static List<MosqueRef> ParseLinkResults(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var refs = new List<MosqueRef>();
            var seen = new HashSet<string>();
            foreach (var it in doc.RootElement.EnumerateArray())
            {
                var name = Str(it, "name");
                var url = Str(it, "url");
                if (name.Length == 0 || url.Length == 0 || !seen.Add(MosqueUrls.Normalize(url))) continue;
                refs.Add(new MosqueRef { Name = name, City = Str(it, "city"), Url = url });
            }
            return refs;
        }
        catch (JsonException) { return new(); }
    }
}

/// <summary>Result of running a script in a loaded page.</summary>
public readonly record struct WebPageResult(string? Json, string? FinalUrl);

/// <summary>Loads a page in a hidden browser and evaluates a script that returns a JSON string.</summary>
public interface IWebPageRunner
{
    Task<WebPageResult> EvaluateAsync(string url, string script, TimeSpan settleDelay, CancellationToken ct);
}

/// <summary>Extraction scripts shared with the Mac app (WKWebView there, WebView2 here).</summary>
public static class Scripts
{
    public const string ExtractSearchLinks = """
        (function() {
            var seen = {}; var out = [];
            var anchors = document.querySelectorAll('a[href*="/m/"]');
            for (var i = 0; i < anchors.length; i++) {
                var a = anchors[i]; var href = a.href || '';
                if (href.indexOf('/m/') < 0 || href.indexOf('mawaqit.net') < 0 || seen[href]) continue;
                seen[href] = true;
                var c = a.closest('li, article, .mosque, .mosque-card, .search-result, .result, div') || a;
                var name = (a.textContent || '').trim();
                if (!name) { var h = c.querySelector('h1,h2,h3,h4,h5,.name,.title'); if (h) name = (h.textContent || '').trim(); }
                if (!name) name = href.split('/m/').pop().replace(/-/g,' ');
                var city = ''; var ce = c.querySelector('.city, .localisation, .address, small, .subtitle, p');
                if (ce) city = (ce.textContent || '').trim();
                out.push({name: name.substring(0, 200), city: city.substring(0, 200), url: href});
            }
            return JSON.stringify(out);
        })();
        """;

    /// <summary>Reads <c>confData</c> and returns it whole; parsed by <see cref="MawaqitClient.ParseConfData"/>.</summary>
    public const string ExtractMosque = """
        (function() {
            try {
                var d = null;
                if (typeof confData !== 'undefined') d = confData;
                else if (window.confData) d = window.confData;
                if (!d && window.mawaqit && window.mawaqit.confData) d = window.mawaqit.confData;
                return d ? JSON.stringify(d) : null;
            } catch (e) { return null; }
        })();
        """;
}
