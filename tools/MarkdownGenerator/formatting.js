export function toSlug(text) {
    return encodeURIComponent(text.toLowerCase().replace(/ - /g, ' ').replace(/ /g, '-'));
}

export function toMetaDate(date) {
    try {
        return new Date(date).toISOString().split('T')[0];
    } catch {
        console.error('Not a date', date);
        return '(invalid date)'
    }
}

export function toDisplayDate(date) {
    try {
        return new Date(date).toISOString().split('T')[0];
    } catch {
        console.error('Not a date', date);
        return new Date().toISOString().split('T')[0];
    }
}
