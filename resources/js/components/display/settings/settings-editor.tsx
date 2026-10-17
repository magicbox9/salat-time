import { AppearanceSection } from './appearance-section';
import { AudioSection } from './audio-section';
import type { EditorProps } from './editor-types';
import { NightSection } from './night-section';
import { RotationSection } from './rotation-section';
import { TimingSection } from './timing-section';

/** Every display setting a mosque and a person share, section by section. */
export function SettingsEditor(props: EditorProps) {
    return (
        <div className="grid gap-6">
            <AppearanceSection {...props} />
            <TimingSection {...props} />
            <RotationSection {...props} />
            <AudioSection {...props} />
            <NightSection {...props} />
        </div>
    );
}
