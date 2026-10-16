import type { DayView, HubPrefs } from '../types';
import { ArcView } from './arc-view';
import { CardsView } from './cards-view';
import { DialView } from './dial-view';
import { MinimalView } from './minimal-view';
import { TimelineView } from './timeline-view';

type Props = {
    view: DayView;
    prefs: HubPrefs;
    /** Southern hemisphere: the moon's lit side is mirrored. */
    southern: boolean;
    now: Date;
};

/** Today's times in the style the visitor chose. */
export function TimesDisplay({ view, prefs, southern, now }: Props) {
    switch (prefs.style) {
        case 'timeline':
            return <TimelineView view={view} prefs={prefs} />;
        case 'arc':
            return (
                <ArcView
                    view={view}
                    prefs={prefs}
                    southern={southern}
                    now={now}
                />
            );
        case 'dial':
            return (
                <DialView
                    view={view}
                    prefs={prefs}
                    southern={southern}
                    now={now}
                />
            );
        case 'minimal':
            return <MinimalView view={view} prefs={prefs} />;
        default:
            return <CardsView view={view} prefs={prefs} />;
    }
}
