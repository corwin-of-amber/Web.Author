<template>
    <span :class="{editing}" :contenteditable="editing"
        @click="click" @keydown="key" @blur="blur"><slot/></span>
</template>

<style scoped>
span.editing {
    overflow: hidden;  /* prevent horizontal scrollbar from interfering */
}
</style>

<script>
import $ from 'jquery';

export default {
    data: () => ({editing: false}),
    methods: {
        edit() {
            this._content = $(this.$el.childNodes).clone();
            this.editing = true;
            window.requestAnimationFrame(() => {
                selectElement(this.$el); this.$el.focus();
            });
        },
        stop() {
            this.editing = false;
            this._content = null;
            this.$el.scrollLeft = 0;
            clearSelection();
        },
        accept() {
            var text = $(this.$el).text();
            if (text == '') this.abort();
            else {
                this.$emit('input', text);
                this.stop();
            }
        },
        abort() {
            $(this.$el).html(this._content);
            this.stop();
        },
        click(ev) {
            if (this.editing) ev.stopPropagation();
        },
        key(ev) {
            if (this.editing) {
                if (ev.key === 'Enter')        { this.accept(); ev.preventDefault(); }
                else if (ev.key === 'Escape')  { this.abort();  ev.preventDefault(); }
            }
        },
        blur(ev) {
            if (this.editing) { this.accept(); }
        }
    }
}

function _getSelection() {
    return window.getSelection ? window.getSelection() : document.selection;
}

function selectElement(el) {
    var range = document.createRange();
    range.selectNodeContents(el);
    var sel = _getSelection();
    sel.empty();
    sel.addRange(range);
}

function clearSelection() {
    var sel = _getSelection();
    if (sel) sel.empty();
}
</script>