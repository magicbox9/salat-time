import { usePage } from '@inertiajs/react';
import { RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    Sheet,
    SheetContent,
    SheetDescription,
    SheetHeader,
    SheetTitle,
} from '@/components/ui/sheet';
import { useT } from '@/lib/i18n';
import type { AdhanTrack, HubPrefs } from '../types';
import { AdhanSettings } from './adhan-settings';
import { Segmented, SheetSection, SwitchRow } from './controls';
import { StylePicker } from './style-picker';

type Props = {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    prefs: HubPrefs;
    signedIn: boolean;
    tracks: AdhanTrack[];
    tracksLoaded: boolean;
    playing: boolean;
    onChange: (change: Partial<HubPrefs>) => void;
    onReset: () => void;
    onPreview: (url: string) => void;
    onStop: () => void;
};

/** "Customise": how the times look, and the adhan inside the page. Changes apply at once. */
export function CustomiseSheet({
    open,
    onOpenChange,
    prefs,
    signedIn,
    tracks,
    tracksLoaded,
    playing,
    onChange,
    onReset,
    onPreview,
    onStop,
}: Props) {
    const t = useT();
    const { dir } = usePage().props;

    return (
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent
                side={dir === 'rtl' ? 'left' : 'right'}
                className="w-full gap-0 overflow-y-auto p-0 sm:max-w-md"
            >
                <SheetHeader className="border-b px-5 py-4">
                    <SheetTitle>{t('hub.custom_title')}</SheetTitle>
                    <SheetDescription>
                        {signedIn
                            ? t('hub.custom_saved_account')
                            : t('hub.custom_saved_device')}
                    </SheetDescription>
                </SheetHeader>

                <SheetSection title={t('hub.custom_style')}>
                    <div className="pt-2">
                        <StylePicker
                            value={prefs.style}
                            onChange={(style) => onChange({ style })}
                        />
                    </div>
                </SheetSection>

                <SheetSection title={t('hub.custom_display')}>
                    <SwitchRow
                        label={t('hub.show_iqama')}
                        checked={prefs.show_iqama}
                        onChange={(show_iqama) => onChange({ show_iqama })}
                    />
                    <SwitchRow
                        label={t('hub.show_seconds')}
                        checked={prefs.show_seconds}
                        onChange={(show_seconds) => onChange({ show_seconds })}
                    />
                    <SwitchRow
                        label={t('hub.show_hijri')}
                        checked={prefs.show_hijri}
                        onChange={(show_hijri) => onChange({ show_hijri })}
                    />
                    <SwitchRow
                        label={t('hub.compact')}
                        hint={t('hub.compact_hint')}
                        checked={prefs.compact}
                        onChange={(compact) => onChange({ compact })}
                    />
                    <Segmented
                        label={t('hub.clock')}
                        value={prefs.clock}
                        onChange={(clock) => onChange({ clock })}
                        options={[
                            { value: '24h', label: t('hub.clock_24') },
                            { value: '12h', label: t('hub.clock_12') },
                        ]}
                    />
                </SheetSection>

                <SheetSection title={t('hub.custom_adhan')}>
                    <AdhanSettings
                        prefs={prefs}
                        tracks={tracks}
                        loaded={tracksLoaded}
                        playing={playing}
                        onChange={onChange}
                        onPreview={onPreview}
                        onStop={onStop}
                    />
                </SheetSection>

                <div className="mt-auto border-t px-5 py-4">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={onReset}
                        className="text-muted-foreground"
                    >
                        <RotateCcw />
                        {t('hub.custom_reset')}
                    </Button>
                </div>
            </SheetContent>
        </Sheet>
    );
}
