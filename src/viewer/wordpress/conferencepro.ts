import {LitElement, html, css} from 'lit';
import {customElement, property, query} from 'lit/decorators.js';


class WPShortCodeElement extends LitElement {

    createRenderRoot() {
        return this; // sorry! WP theme CSS does not expect shadow DOM!
    }

    slotIn(contentSel: string, slotSel: string) {
        var content = this.querySelector(contentSel),
            slot = this.querySelector(slotSel);
        if (content && slot) slot.replaceWith(content);
    }

    slotsIn(sels: {[contentSel: string]: string}) {
        for (let [contentSel, slotSel] of Object.entries(sels))
            this.slotIn(contentSel, slotSel);
    }

    delayedSlotsIn(sels: {[contentSel: string]: string}) {
        var ob = new MutationObserver(() => this.slotsIn(sels));
        ob.observe(this, {childList: true, subtree: true});
    }
}


@customElement('efcb-section-heading')
class SectionHeading extends WPShortCodeElement {
    @property() id = ""
    @property() title = ""
    @property() title_icon: string
    @property() subtitle = ""
    @property() text = ""

    render() {
        return html`
        <div class="content content__text-block heading ef-fe-element" id=${this.id}>
            <h2 class="site__title site__title_logo site__title_sponsors" >
                <!-- title_icon -->
                    <span class="title_icon"><i
                            class="fa fa-${this.title_icon}"></i></span>
                <!-- /title_icon -->
                <span>${this.text}</span>
                <span class="site__title-info">${this.subtitle}</span>
            </h2>
        </div>`;
    }
}


@customElement('efcb-section-columns-2')
class SectionColumns2 extends WPShortCodeElement {
    @property() id: string

    render() {
        this.delayedSlotsIn({content1: 'slot[name=content1]',
                             content2: 'slot[name=content2]'});
        return html`
        <div class="row clearfix content ef-fe-element" id=${this.id}>
            <div class="col col-md-6 content1">
                <slot name="content1"></slot>
            </div>
            <div class="col col-md-6 content2" >
                <slot name="content2"></slot>
            </div>
        </div>`;
    }
}


@customElement('efcb-section-news')
class SectionNews extends WPShortCodeElement {
    @property() id: string
    @property() title = ""
    @property() title_icon: string
    @property() view_button_text = ""
    @property() view_all_button_text = "" 
    @property() view_all_button_url = "" 
    @property() background_color = " " 
    @property() title_font_color = " " 
    @property() news_title_font_color = " " 
    @property() news_subtitle_font_color = " " 
    @property() news_date_font_color = " " 
    @property() news_box_background_color = " " 
    @property() entities: string

    render() {
        var entities = [{id: this.entities, title: "news title", excerpt: "Some stuff happened", permalink: "#", image_style: {}, date: "now"}];
        return html`
        <section class="news news_inner ef-fe-element" id=${this.id}>
            <div class="site__centered">
                ${this.title ? html`
                <h2 class="site__title site__title_logo site__title_news">
                    <span class="title_icon"><i class="fa fa-${this.title_icon}"></i></span>
                    <span>${this.title || "no title"}</span>
                </h2>` : []}
                <div class="news__layout">
                    ${entities.map(news => html`
                    <article class="news__article" data-id=${news.id}>
                        <a href=${news.permalink}>
                            <div class="news__picture" ${news.image_style}></div>
                            <div class="news__content">
                                <div>
                                    <h2 class="news__title">${news.title}</h2>
                                    <div class="news__text">
                                        <p>${news.excerpt}</p>
                                    </div>
                                </div>
                                <time datetime=${news.date}
                                    class="news__date">${news.date}</time>
                            </div>
                        </a>
                    </article>`)}
                </div>
            </div>
        </section>
        `;
    }
}


@customElement('efcb-section-html')
class SectionHtml extends WPShortCodeElement {
    @property() id = ""

    render() {
        this.delayedSlotsIn({content: 'slot'});
        return html`
        <div class="content ef-fe-element" id=${this.id}>
            <div class="site__text">
                <slot></slot>
            </div>
        </div>`;
    }
}


export { SectionHeading, SectionColumns2, SectionNews, SectionHtml }