<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use Illuminate\Database\Eloquent\Builder;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * A mosque's donations as CSV (for its accounts and tax receipts). Opened in
 * a spreadsheet, a cell that starts with = + - @ or a control character
 * would run as a formula: such cells are prefixed with an apostrophe.
 */
class DonationCsv
{
    private const HEADERS = ['date', 'reference', 'campaign', 'donor_name', 'donor_email', 'anonymous', 'amount', 'currency',
        'method', 'status', 'message', 'confirmed_at'];

    /** @param  Builder<Donation>  $query */
    public function download(Builder $query, string $filename, string $timezone): StreamedResponse
    {
        return response()->streamDownload(function () use ($query, $timezone) {
            $out = fopen('php://output', 'w');
            if ($out === false) {
                return;
            }
            fwrite($out, "\xEF\xBB\xBF");   // UTF-8 BOM: accents and Arabic open correctly in Excel
            fputcsv($out, array_map(fn (string $h) => ui('fundraising.csv_'.$h), self::HEADERS), escape: '');

            $query->with('campaign:id,title')->orderBy('id')->chunkById(500, function ($donations) use ($out, $timezone) {
                foreach ($donations as $donation) {
                    fputcsv($out, array_map([self::class, 'cell'], $this->row($donation, $timezone)), escape: '');
                }
            });
            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    /** @return list<string> */
    private function row(Donation $donation, string $timezone): array
    {
        return [
            ModelDate::of($donation, 'created_at')?->setTimezone($timezone)->format('Y-m-d H:i') ?? '',
            $donation->reference,
            $this->campaignTitle($donation),
            (string) $donation->donor_name,
            (string) $donation->donor_email,
            $donation->anonymous ? 'yes' : 'no',
            number_format($donation->amount / 100, 2, '.', ''),
            $donation->currency,
            $donation->method,
            $donation->status,
            (string) $donation->message,
            ModelDate::of($donation, 'confirmed_at')?->setTimezone($timezone)->format('Y-m-d H:i') ?? '',
        ];
    }

    private function campaignTitle(Donation $donation): string
    {
        $campaign = $donation->getRelationValue('campaign');

        return $campaign instanceof Campaign ? $campaign->title : '';
    }

    /** Neutralises spreadsheet formulas (CSV injection). */
    public static function cell(string $value): string
    {
        $value = str_replace("\0", '', $value);

        return preg_match('/^[=+\-@\t\r\n|%]/', $value) ? "'".$value : $value;
    }
}
