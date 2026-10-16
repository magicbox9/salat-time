import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, BadgeCheck, Building2, Clock, MapPin } from 'lucide-react';
import { ClaimExplainer } from '@/components/claims/claim-explainer';
import { ClaimForm } from '@/components/claims/claim-form';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    manages: boolean;
    pendingClaim: { id: number; created_at: string | null } | null;
    documentMaxMb: number;
};

/** /mosques/{slug}/claim — ask to manage a mosque's page. */
export default function ClaimCreate({
    mosque,
    manages,
    pendingClaim,
    documentMaxMb,
}: Props) {
    const t = useT();
    const formatDate = useFormatDate();
    const place = [
        mosque.address,
        [mosque.postcode, mosque.city].filter(Boolean).join(' '),
    ]
        .filter(Boolean)
        .join(', ');

    return (
        <>
            <Head title={t('claims.create_title', { name: mosque.name })} />

            <Link
                href={`/mosques/${mosque.slug}`}
                className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
                <ArrowLeft className="size-4 rtl:rotate-180" aria-hidden />
                {t('claims.back_to_mosque')}
            </Link>

            <header className="mt-4 mb-8">
                <p className="text-sm font-medium text-amber-700 dark:text-gold">
                    {t('claims.eyebrow')}
                </p>
                <h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">
                    {mosque.name}
                </h1>
                <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
                    {place && (
                        <span className="inline-flex items-center gap-1">
                            <MapPin className="size-4" aria-hidden />
                            {place}
                        </span>
                    )}
                    {mosque.verified && (
                        <Badge
                            variant="outline"
                            className="rounded-full border-primary/30 text-primary"
                        >
                            <BadgeCheck aria-hidden />
                            {t('claims.mosque_verified')}
                        </Badge>
                    )}
                </div>
            </header>

            <div className="grid items-start gap-6 lg:grid-cols-5">
                <ClaimExplainer className="lg:col-span-2" />

                <section className="rounded-xl border bg-card p-5 shadow-sm sm:p-6 lg:col-span-3">
                    {manages ? (
                        <StateMessage
                            icon={<Building2 className="size-5" aria-hidden />}
                            title={t('claims.state_manager_title')}
                            text={t('claims.state_manager_text')}
                            href="/manage"
                            action={t('claims.open_manage')}
                        />
                    ) : pendingClaim ? (
                        <StateMessage
                            icon={<Clock className="size-5" aria-hidden />}
                            title={t('claims.state_pending_title')}
                            text={t('claims.state_pending_text', {
                                date: formatDate(pendingClaim.created_at),
                            })}
                            href="/me/claims"
                            action={t('claims.see_my_requests')}
                        />
                    ) : (
                        <>
                            <h2 className="text-lg font-semibold">
                                {t('claims.form_title')}
                            </h2>
                            <p className="mt-1 mb-6 text-sm text-muted-foreground">
                                {t('claims.form_intro')}
                            </p>
                            <ClaimForm
                                slug={mosque.slug}
                                documentMaxMb={documentMaxMb}
                            />
                        </>
                    )}
                </section>
            </div>
        </>
    );
}

function StateMessage({
    icon,
    title,
    text,
    href,
    action,
}: {
    icon: React.ReactNode;
    title: string;
    text: string;
    href: string;
    action: string;
}) {
    return (
        <div className="flex flex-col items-start gap-4 py-2">
            <span className="flex size-10 items-center justify-center rounded-full bg-primary/10 text-primary">
                {icon}
            </span>
            <div>
                <h2 className="text-lg font-semibold">{title}</h2>
                <p className="mt-1 text-sm text-muted-foreground">{text}</p>
            </div>
            <Button asChild>
                <Link href={href}>{action}</Link>
            </Button>
        </div>
    );
}
