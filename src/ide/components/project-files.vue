<template>
    <div class="project-files" @contextmenu.prevent="$refs.contextMenu.open">
        <file-list ref="list" :files="files" @action="act"/>
        <component :is="sourceType" ref="source" :path="path"></component>
        <project-context-menu ref="contextMenu" @action="onmenuaction"/>
    </div>  
</template>

<script>
import { ProjectView } from '../project.ls';
import FileList from '../../../packages/file-list/index.vue';
import ProjectContextMenu from './project-context-menu.vue';

export default {
    props: ['path'],
    data: () => ({files: []}),
    computed: {
        sourceType() { return ProjectView.detectFolderSource(this.path); }
    },
    mounted() {
        this.$watch('path', () => {                        // it is quite unfortunate that this cannot
            this.files = this.$refs.source?.files || [];   // be done with a computed property
            this.$refs.list.collapseAll();
        }, {immediate: true});
    },
    methods: {
        refresh() { this.$refs.source?.refresh(); },
        act(ev) {
            console.log(ev);
            switch (ev.type) {
            case 'select':
                if (ev.kind == 'file')
                    this.$emit('file:select', this.$refs.source.getPathOf(ev.path));
                break;
            case 'menu':
                this.$refs.contextMenu.open(ev.$event);
                ev.$event.preventDefault();
                break;
            }
        },
        onmenuaction(ev) {
            switch (ev.name) {
            case 'new-file': this.create(); break;
            case 'rename':   this.rename(); break;
            }
        },
        create() {
            this.$refs.source.create('new-file1.tex');
        },
        rename() {
            var sel = this.$refs.list.selection[0];
            if (sel !== undefined)
                this.$refs.list.renameStart(sel);
        }
    },
    components: {FileList, ProjectContextMenu}
}
</script>
