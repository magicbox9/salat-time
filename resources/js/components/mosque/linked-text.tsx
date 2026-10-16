import { Fragment } from 'react';
import { cn } from '@/lib/utils';

const URL_PATTERN = /(https?:\/\/[^\s<>"']+[^\s<>"'.,;:!?)\]}])/gi;

/**
 * Plain text written by a mosque or a visitor: line breaks kept, http(s) links
 * made clickable. Rendered as React text nodes only — never as HTML.
 */
export function LinkedText({
    text,
    className,
}: {
    text: string;
    className?: string;
}) {
    const parts = text.split(URL_PATTERN);

    return (
        <p className={cn('break-words whitespace-pre-line', className)}>
            {parts.map((part, index) =>
                index % 2 === 1 ? (
                    <a
                        key={index}
                        href={part}
                        target="_blank"
                        rel="noopener noreferrer nofollow ugc"
                        className="text-primary underline underline-offset-2 hover:no-underline"
                        dir="ltr"
                    >
                        {part}
                    </a>
                ) : (
                    <Fragment key={index}>{part}</Fragment>
                ),
            )}
        </p>
    );
}
