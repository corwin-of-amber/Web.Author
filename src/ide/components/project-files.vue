<template>
    <div class="project-files" @contextmenu.prevent="$refs.contextMenu.open">
        <file-list ref="list" :files="files" @action="act"/>
        <component :is="sourceType" ref="source" :loc="loc" :opts="opts"></component>
        <project-context-menu ref="contextMenu" @action="onmenuaction"/>
    </div>  
</template>

<script>
import { ProjectView } from '../project.ls';
import FileList from '../../../packages/file-list/index.vue';
import ProjectContextMenu from './project-context-menu.vue';

export default {
    props: ['loc', 'opts'],
    data: () => ({files: []}),
    computed: {
        sourceType() { return this.loc && ProjectView.detectFolderSource(this.loc); }
    },
    mounted() {
        this.$watch('loc', () => {                         // it is quite unfortunate that this cannot
            this.files = this.$refs.source?.files || [];   // be done with a computed property
            this.$refs.list.collapseAll();
        }, {immediate: true});
    },
    methods: {
        refresh() { this.$refs.source?.refresh(); },
        act(ev) {
            switch (ev.type) {
            case 'select':
                if (ev.kind == 'file')
                    this.$emit('file:select', this._volPath(ev.path));
                break;
            case 'create': this.create(ev, {focus: true}); break;
            case 'rename': this.rename(ev, {focus: true}); break;
            case 'menu':
                this.$refs.contextMenu.open(ev.$event, ev);
                ev.$event.preventDefault();
                break;
            }
        },
        onmenuaction(ev) {
            switch (ev.type) {
            case 'new-file': this.create(ev, {promptName: true}); break;
            case 'rename':   this.renameStart(ev); break;
            case 'delete':   this.delete(ev); break;
            case 'refresh':  this.$emit('action', {type: 'refresh'}); break;
            }
        },
        /** May be called either from a context menu action or a dropped file */
        async create(ev, {promptName, focus} = {}) {
            if (focus) this._defer(() => this.select(fn)); // has to take place before `await` :(

            var fv = this.$refs.list,
                fn = ev.path ?? fv.freshName(ev.for?.path ?? [], 'new-file#.tex'),
                vol = this.$refs.source.volume, path = vol.path,
                content = await this._fileContent(ev.content ?? '');
            vol.writeFileSync(path.join(...fn), content);
            fv.create(fn);
            if (promptName) setTimeout(() => fv.renameStart(fn), 0);
        },
        renameStart(ev) {
            this.$refs.list.renameStart(ev.for.path);
        },
        rename(ev, {focus} = {}) {
            var vol = this.$refs.source.volume, path = vol.path,
                from = path.join(...ev.path, ev.from),
                to   = path.join(...ev.path, ev.to);
            vol.renameSync(from, to);
            if (focus) this.select(to);
        },
        delete(ev) {
            var vol = this.$refs.source.volume, path = vol.path;
            vol.unlinkSync(path.join(...ev.for.path));
            this.$refs.list.delete(ev.for.path);
        },
        select(path, {silent} = {}) {
            var fv = this.$refs.list, entry = fv.lookup(path);
            if (entry) {
                fv.select(path);
                if (!silent && !entry.files)
                    this.$emit('file:select', this._volPath(path));
            }
        },
        _volPath(path) {
            return Array.isArray(path) ? 
                this.$refs.source.volume.path.join(...path) : path;
        },
        async _fileContent(content) {
            return content instanceof Blob ?
                new Uint8Array(await content.arrayBuffer()) : content;
        },
        _defer(op) {
            if (!this._deferred)
                Promise.resolve().then(() => {
                    this._deferred(); this._deferred = null; 
                });
            this._deferred = op;
        }
    },
    components: {FileList, ProjectContextMenu}
}
</script>
