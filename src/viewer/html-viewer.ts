import $ from 'jquery';
import { EventEmitter } from 'events';


class HTMLViewerCore extends EventEmitter {
    html: HTMLDocument
    content: JQuery<HTMLIFrameElement>

    constructor(html: HTMLDocument, container: JQuery<HTMLElement>) {
        super();
        this.content = $('<iframe>');
        this.content.addClass('viewer--html');
        if (html) this.open(html);
        container.append(this.content);
    }

    destroy() {
        this.content.remove();
    }

    open(html: HTMLDocument) {
        this.content[0].srcdoc = html.source;
    }
}

class HTMLDocument {
    source: string

    constructor(source: string) { this.source = source; }
}

class HTMLViewer extends HTMLViewerCore {

}


export { HTMLViewerCore, HTMLDocument, HTMLViewer }
