import {
    Bold,
    Heading2,
    Italic,
    Link2,
    List,
    ListOrdered,
    Quote,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useEffect, useId, useRef, useState } from 'react';
import { MarkdownContent } from '@/components/markdown-content';
import { api } from '@/components/mosque/api';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { Textarea } from './fields';
import { applyMarkdown } from './markdown-toolbar';
import type { MarkdownAction } from './markdown-toolbar';

type Props = {
    id: string;
    value: string;
    onChange: (value: string) => void;
    /** The mosque whose manager is writing (POST /manage/{slug}/markdown-preview). */
    mosqueSlug: string;
    maxLength: number;
    rows?: number;
    invalid?: boolean;
    required?: boolean;
};

const TOOLS: {
    action: MarkdownAction;
    icon: LucideIcon;
    key: string;
    shortcut?: string;
}[] = [
    { action: 'heading', icon: Heading2, key: 'manage.md_heading' },
    { action: 'bold', icon: Bold, key: 'manage.md_bold', shortcut: 'b' },
    { action: 'italic', icon: Italic, key: 'manage.md_italic', shortcut: 'i' },
    { action: 'link', icon: Link2, key: 'manage.md_link', shortcut: 'k' },
    { action: 'list', icon: List, key: 'manage.md_list' },
    { action: 'ordered', icon: ListOrdered, key: 'manage.md_ordered' },
    { action: 'quote', icon: Quote, key: 'manage.md_quote' },
];

type Mode = 'write' | 'preview' | 'split';

/**
 * A Markdown textarea with a small toolbar and a live preview. The preview is
 * rendered by the server, exactly as visitors will see it (raw HTML removed,
 * unsafe links refused), a moment after typing stops.
 */
export function MarkdownEditor({
    id,
    value,
    onChange,
    mosqueSlug,
    maxLength,
    rows = 14,
    invalid,
    required,
}: Props) {
    const t = useT();
    const tabs = useId();
    const area = useRef<HTMLTextAreaElement>(null);
    const [mode, setMode] = useState<Mode>('write');
    const [html, setHtml] = useState('');
    const [loading, setLoading] = useState(false);
    const [failed, setFailed] = useState(false);
    const showPreview = mode !== 'write';

    useEffect(() => {
        if (!showPreview) {
            return;
        }

        const controller = { cancelled: false };
        const timer = window.setTimeout(async () => {
            setLoading(true);

            try {
                const answer = await api<{ html: string }>(
                    'POST',
                    `/manage/${mosqueSlug}/markdown-preview`,
                    { body: value },
                );

                if (!controller.cancelled) {
                    setHtml(answer.html);
                    setFailed(false);
                }
            } catch {
                if (!controller.cancelled) {
                    setFailed(true);
                }
            } finally {
                if (!controller.cancelled) {
                    setLoading(false);
                }
            }
        }, 600);

        return () => {
            controller.cancelled = true;
            window.clearTimeout(timer);
        };
    }, [value, showPreview, mosqueSlug]);

    const apply = (action: MarkdownAction) => {
        const el = area.current;

        if (!el) {
            return;
        }

        const next = applyMarkdown(
            action,
            { value, start: el.selectionStart, end: el.selectionEnd },
            {
                text: t('manage.md_text_placeholder'),
                link: t('manage.md_link_placeholder'),
            },
        );

        if (next.value.length > maxLength) {
            return;
        }

        onChange(next.value);
        requestAnimationFrame(() => {
            el.focus();
            el.setSelectionRange(next.start, next.end);
        });
    };

    const modes: Mode[] = ['write', 'preview', 'split'];

    return (
        <div
            className={cn(
                'overflow-hidden rounded-xl border bg-background shadow-xs focus-within:ring-[3px] focus-within:ring-ring/40',
                invalid && 'border-destructive',
            )}
        >
            <div className="flex flex-wrap items-center justify-between gap-2 border-b bg-muted/40 px-2 py-1.5">
                <div
                    role="toolbar"
                    aria-label={t('manage.md_toolbar')}
                    aria-controls={id}
                    className="flex flex-wrap gap-0.5"
                >
                    {TOOLS.map((tool) => (
                        <button
                            key={tool.action}
                            type="button"
                            onClick={() => apply(tool.action)}
                            disabled={mode === 'preview'}
                            title={
                                t(tool.key) +
                                (tool.shortcut
                                    ? ` (Ctrl/⌘ ${tool.shortcut.toUpperCase()})`
                                    : '')
                            }
                            aria-label={t(tool.key)}
                            className="flex size-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-background hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:outline-none disabled:opacity-40"
                        >
                            <tool.icon className="size-4" />
                        </button>
                    ))}
                </div>
                <div
                    role="tablist"
                    aria-label={t('manage.md_view')}
                    className="flex rounded-lg bg-background p-0.5 text-xs font-medium shadow-xs"
                >
                    {modes.map((m) => (
                        <button
                            key={m}
                            type="button"
                            role="tab"
                            id={`${tabs}-${m}`}
                            aria-selected={mode === m}
                            onClick={() => setMode(m)}
                            className={cn(
                                'rounded-md px-2.5 py-1 transition-colors',
                                m === 'split' && 'hidden lg:block',
                                mode === m
                                    ? 'bg-primary text-primary-foreground'
                                    : 'text-muted-foreground hover:text-foreground',
                            )}
                        >
                            {t(`manage.md_${m}`)}
                        </button>
                    ))}
                </div>
            </div>

            <div
                className={cn(
                    mode === 'split' &&
                        'lg:grid lg:grid-cols-2 lg:divide-x rtl:lg:divide-x-reverse',
                )}
            >
                <div className={cn(mode === 'preview' && 'hidden')}>
                    <Textarea
                        ref={area}
                        id={id}
                        rows={rows}
                        maxLength={maxLength}
                        required={required}
                        value={value}
                        dir="auto"
                        aria-invalid={invalid || undefined}
                        onChange={(event) => onChange(event.target.value)}
                        onKeyDown={(event) => {
                            const tool = TOOLS.find(
                                (x) => x.shortcut === event.key.toLowerCase(),
                            );

                            if ((event.metaKey || event.ctrlKey) && tool) {
                                event.preventDefault();
                                apply(tool.action);
                            }
                        }}
                        className="min-h-64 resize-y rounded-none border-0 font-mono text-sm leading-relaxed shadow-none focus-visible:ring-0"
                    />
                </div>
                {showPreview && (
                    <div
                        role="region"
                        aria-label={t('manage.md_preview')}
                        aria-busy={loading}
                        className="relative min-h-64 overflow-auto p-4"
                    >
                        {loading && (
                            <Spinner className="absolute end-3 top-3" />
                        )}
                        {failed ? (
                            <p className="text-sm text-muted-foreground">
                                {t('manage.md_preview_failed')}
                            </p>
                        ) : html ? (
                            <MarkdownContent html={html} className="text-sm" />
                        ) : (
                            <p className="text-sm text-muted-foreground">
                                {loading ? '' : t('manage.md_preview_empty')}
                            </p>
                        )}
                    </div>
                )}
            </div>
            <div className="flex flex-wrap items-center justify-between gap-2 border-t bg-muted/30 px-3 py-1.5 text-xs text-muted-foreground">
                <span>{t('manage.md_hint')}</span>
                <span className="tabular-nums" dir="ltr">
                    {value.length.toLocaleString()}/{maxLength.toLocaleString()}
                </span>
            </div>
        </div>
    );
}
