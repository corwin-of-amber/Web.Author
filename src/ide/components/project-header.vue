<template>
    <div class="project-header">
        <!-- <p2p.source-status ref="status" channel="doc2"/> -->
        <div class="bar" @click.prevent.stop="$refs.list.toggle">
            <span>{{name}}</span>
            <button name="build" class="badge hammer" title="Build project" 
                    :class="buildStatus" @click.stop="$emit('build')">⚒</button>
            <!-- <button class="badge p2p" :class="p2pStatus" @click.stop="toggle">❂</button> -->
        </div>
        <project-list-dropdown ref="list" :items="projects || []" @action="$emit('action', $event)"/>
    </div>  
</template>

<script>
import ProjectListDropdown from './project-list-dropdown.vue';

export default {
    props: ['name', 'build-status', 'projects'],
    data: () => ({p2pStatus: undefined}),
    methods: {
        toggle() { this.$refs.status.toggle(); }
    },
    components: {ProjectListDropdown}
}
</script>

<style>

</style>