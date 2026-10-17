/** Text edits behind the Markdown editor's toolbar buttons. */
export type MarkdownAction =
    | 'heading'
    | 'bold'
    | 'italic'
    | 'link'
    | 'list'
    | 'ordered'
    | 'quote';

type Edit = { value: string; start: number; end: number };

function wrap(
    edit: Edit,
    before: string,
    after: string,
    placeholder: string,
): Edit {
    const selected = edit.value.slice(edit.start, edit.end) || placeholder;
    const value =
        edit.value.slice(0, edit.start) +
        before +
        selected +
        after +
        edit.value.slice(edit.end);
    const start = edit.start + before.length;

    return { value, start, end: start + selected.length };
}

/** Prefixes every line touched by the selection ("## ", "- ", "1. ", "> "). */
function prefixLines(edit: Edit, prefix: (index: number) => string): Edit {
    const lineStart = edit.value.lastIndexOf('\n', edit.start - 1) + 1;
    const nextBreak = edit.value.indexOf('\n', edit.end);
    const lineEnd = nextBreak === -1 ? edit.value.length : nextBreak;
    const lines = edit.value.slice(lineStart, lineEnd).split('\n');
    const block = lines
        .map(
            (line, i) =>
                prefix(i) + line.replace(/^(#{1,6} |[-*] |\d+\. |> )/, ''),
        )
        .join('\n');
    const value =
        edit.value.slice(0, lineStart) + block + edit.value.slice(lineEnd);

    return { value, start: lineStart, end: lineStart + block.length };
}

export function applyMarkdown(
    action: MarkdownAction,
    edit: Edit,
    placeholders: Record<string, string>,
): Edit {
    switch (action) {
        case 'bold':
            return wrap(edit, '**', '**', placeholders.text);
        case 'italic':
            return wrap(edit, '_', '_', placeholders.text);
        case 'link': {
            const label =
                edit.value.slice(edit.start, edit.end) || placeholders.link;
            const value = `${edit.value.slice(0, edit.start)}[${label}](https://)${edit.value.slice(edit.end)}`;
            const start = edit.start + label.length + 3;

            return { value, start, end: start + 8 };
        }
        case 'heading':
            return prefixLines(edit, () => '## ');
        case 'list':
            return prefixLines(edit, () => '- ');
        case 'ordered':
            return prefixLines(edit, (i) => `${i + 1}. `);
        case 'quote':
            return prefixLines(edit, () => '> ');
    }
}
