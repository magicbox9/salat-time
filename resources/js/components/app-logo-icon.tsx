import { SiteLogoMark } from '@/components/site/site-logo';

/** Starter-kit slot for the logo (auth pages): the Salat Time mark. */
export default function AppLogoIcon({ className }: { className?: string }) {
    return <SiteLogoMark className={className} />;
}
