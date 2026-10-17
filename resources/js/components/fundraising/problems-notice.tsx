import { Link } from '@inertiajs/react';
import { AlertTriangle, ArrowRight } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { EligibilityProblem } from './types';

/**
 * Plain guidance when a campaign cannot go to review yet: what is missing
 * and where to fix it (verification comes from the platform's team).
 */
export function ProblemsNotice({
    problems,
    mosqueSlug,
    title,
}: {
    problems: EligibilityProblem[];
    mosqueSlug: string;
    title?: string;
}) {
    const t = useT();

    if (problems.length === 0) {
        return null;
    }

    return (
        <section
            className="rounded-2xl border border-amber-500/40 bg-amber-500/10 p-4 sm:p-5"
            role="status"
        >
            <h2 className="flex items-center gap-2 font-semibold">
                <AlertTriangle
                    className="size-4 text-amber-700 dark:text-amber-300"
                    aria-hidden
                />
                {title ?? t('fundraising.problems_title')}
            </h2>
            <ul className="mt-3 space-y-2.5 text-sm">
                {problems.map((problem) => (
                    <li key={problem} className="space-y-1">
                        <p className="font-medium">
                            {t(`fundraising.problem_${problem}`)}
                        </p>
                        <p className="text-muted-foreground">
                            {t(`fundraising.problem_${problem}_help`)}
                        </p>
                        {(problem === 'no_verified_payout' ||
                            problem === 'method_unverified') && (
                            <Link
                                href={`/manage/${mosqueSlug}/payouts`}
                                className="inline-flex items-center gap-1 font-medium text-primary hover:underline"
                            >
                                {t('fundraising.go_to_payouts')}
                                <ArrowRight
                                    className="size-3.5 rtl:rotate-180"
                                    aria-hidden
                                />
                            </Link>
                        )}
                        {problem === 'mosque_unverified' && (
                            <Link
                                href={`/manage/${mosqueSlug}`}
                                className="inline-flex items-center gap-1 font-medium text-primary hover:underline"
                            >
                                {t('fundraising.go_to_details')}
                                <ArrowRight
                                    className="size-3.5 rtl:rotate-180"
                                    aria-hidden
                                />
                            </Link>
                        )}
                    </li>
                ))}
            </ul>
        </section>
    );
}
