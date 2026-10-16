import { useState } from 'react';
import { toast } from 'sonner';
import { useT } from '@/lib/i18n';

/** "Use my location": the browser asks for permission; the position never leaves the page except to find mosques. */
export function useGeolocation(
    onPosition: (point: { lat: number; lng: number }) => void,
) {
    const t = useT();
    const [locating, setLocating] = useState(false);

    const locate = () => {
        if (typeof navigator === 'undefined' || !navigator.geolocation) {
            toast.error(t('discover.location_unsupported'));

            return;
        }

        setLocating(true);
        navigator.geolocation.getCurrentPosition(
            (position) => {
                setLocating(false);
                onPosition({
                    lat: position.coords.latitude,
                    lng: position.coords.longitude,
                });
            },
            (error) => {
                setLocating(false);
                toast.error(
                    error.code === error.PERMISSION_DENIED
                        ? t('discover.location_denied')
                        : t('discover.location_failed'),
                );
            },
            { enableHighAccuracy: false, timeout: 12000, maximumAge: 120000 },
        );
    };

    return { locate, locating };
}
