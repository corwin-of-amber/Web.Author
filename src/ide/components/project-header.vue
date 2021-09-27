<template>
    <div class="project-header">
        <!-- <p2p.source-status ref="status" channel="doc2"/> -->
        <div class="bar" :class="{editing: nameEditing}" @click.prevent.stop="menu">
            <span-editable class="name" ref="name" @input="rename">{{name}}</span-editable>
            <button class="badge pencil" @click.prevent.stop="renameStart">✎</button>
            <button name="build" class="badge hammer" title="Build project" 
                    :class="buildStatus" @click.stop="$emit('build')">⚒</button>
            <!-- <button class="badge p2p" :class="p2pStatus" @click.stop="toggle">❂</button> -->
        </div>
        <project-list-dropdown ref="list" :items="projects || []" @action="action($event)"/>
    </div>  
</template>

<style scoped>
.bar.editing .badge,
.bar:not(:hover) .badge.pencil {
    display: none;
}
</style>

<script>
import ProjectListDropdown from './project-list-dropdown.vue';
import SpanEditable from '../../../packages/file-list/span-editable.vue';

export default {
    props: ['name', 'build-status', 'projects'],
    data: () => ({p2pStatus: undefined, nameEditing: false}),
    mounted() {
        this.$watch(() => this.$refs.name.editing, v => this.nameEditing = v);
    },
    methods: {
        toggle() { this.$refs.status.toggle(); },
        menu() { this.$refs.list.open(); },
        renameStart() { this.$refs.name.edit() },
        rename(newName) { this.action({type: 'rename', name: newName}); },
        action(ev) { this.$emit('action', ev) }
    },
    components: { ProjectListDropdown, SpanEditable }
}
</script>

<style>

</style>