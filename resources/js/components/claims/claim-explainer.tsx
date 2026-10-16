import { HandCoins, MessagesSquare, Newspaper, PencilLine } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

/** What managing a mosque's page means, and how a request is reviewed. */
export function ClaimExplainer({ className }: { className?: string }) {
    const t = useT();
    const items = [
        {
            icon: Newspaper,
            title: t('claims.explain_publish_title'),
            text: t('claims.explain_publish'),
        },
        {
            icon: PencilLine,
            title: t('claims.explain_details_title'),
            text: t('claims.explain_details'),
        },
        {
            icon: MessagesSquare,
            title: t('claims.explain_community_title'),
            text: t('claims.explain_community'),
        },
    ];
    const steps = [t('claims.step_1'), t('claims.step_2'), t('claims.step_3')];

    return (
        <aside className={cn('space-y-5', className)}>
            <section className="rounded-xl border bg-card p-5 sm:p-6">
                <h2 className="text-base font-semibold">
                    {t('claims.explain_title')}
                </h2>
                <ul className="mt-4 space-y-4">
                    {items.map((item) => (
                        <li key={item.title} className="flex gap-3">
                            <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                                <item.icon className="size-4" aria-hidden />
                            </span>
                            <div>
                                <p className="text-sm font-medium">
                                    {item.title}
                                </p>
                                <p className="mt-0.5 text-sm text-muted-foreground">
                                    {item.text}
                                </p>
                            </div>
                        </li>
                    ))}
                </ul>
            </section>

            <section className="rounded-xl border border-gold/40 bg-gold/10 p-5 sm:p-6">
                <div className="flex gap-3">
                    <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg bg-gold/20 text-amber-800 dark:text-gold">
                        <HandCoins className="size-4" aria-hidden />
                    </span>
                    <div>
                        <p className="text-sm font-medium">
                            {t('claims.explain_verify_title')}
                        </p>
                        <p className="mt-0.5 text-sm text-muted-foreground">
                            {t('claims.explain_verify')}
                        </p>
                    </div>
                </div>
            </section>

            <section className="rounded-xl border bg-card p-5 sm:p-6">
                <h2 className="text-base font-semibold">
                    {t('claims.steps_title')}
                </h2>
                <ol className="mt-4 space-y-3">
                    {steps.map((step, index) => (
                        <li key={step} className="flex gap-3 text-sm">
                            <span
                                className="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground"
                                dir="ltr"
                            >
                                {index + 1}
                            </span>
                            <span className="pt-0.5 text-muted-foreground">
                                {step}
                            </span>
                        </li>
                    ))}
                </ol>
            </section>
        </aside>
    );
}
