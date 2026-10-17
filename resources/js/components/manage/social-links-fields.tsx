import InputError from '@/components/input-error';
import type { SocialNetwork } from '@/components/mosque/site-types';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';

const EXAMPLES: Record<SocialNetwork, string> = {
    facebook: 'facebook.com/mosquee.exemple',
    instagram: '@mosquee.exemple',
    youtube: '@mosquee-exemple',
    x: '@mosquee_exemple',
    tiktok: '@mosquee.exemple',
    whatsapp: '+33 6 12 34 56 78',
    telegram: 't.me/mosquee_exemple',
};

type Props = {
    networks: SocialNetwork[];
    values: Record<string, string>;
    onChange: (network: SocialNetwork, value: string) => void;
    errors: Record<string, string | undefined>;
};

/** One field per social network: a link or a handle, checked by the server. */
export function SocialLinksFields({
    networks,
    values,
    onChange,
    errors,
}: Props) {
    const t = useT();

    return (
        <div className="grid gap-4 sm:grid-cols-2">
            {networks.map((network) => {
                const id = `social-${network}`;
                const error = errors[`social_links.${network}`];

                return (
                    <div key={network} className="grid gap-1.5">
                        <Label htmlFor={id}>
                            {t(`mosquesite.social_${network}`)}
                        </Label>
                        <Input
                            id={id}
                            dir="ltr"
                            value={values[network] ?? ''}
                            maxLength={300}
                            placeholder={EXAMPLES[network]}
                            autoComplete="off"
                            onChange={(event) =>
                                onChange(network, event.target.value)
                            }
                            aria-invalid={error ? true : undefined}
                        />
                        <InputError message={error} />
                    </div>
                );
            })}
        </div>
    );
}
