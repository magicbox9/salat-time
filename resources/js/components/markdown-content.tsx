import { cn } from '@/lib/utils';

/**
 * Shows Markdown that the SERVER has already turned into safe HTML with
 * App\Support\Markdown::toHtml (raw HTML stripped, unsafe links refused).
 * Never pass anything else to it.
 */
export function MarkdownContent({ html, className }: { html: string; className?: string }) {
    return (
        <div
            className={cn('markdown-content', className)}
            // eslint-disable-next-line react/no-danger -- server-sanitised Markdown only
            dangerouslySetInnerHTML={{ __html: html }}
        />
    );
}
