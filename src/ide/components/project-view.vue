<template>
    <div class="project-view">
        <div class="ide-pane-section project-main">
            <project-header ref="header" :name="name" :build-status="buildStatus"
                :projects="projects" @action="$emit('action', $event)" @build="$emit('build', $event)"/>
            <project-files ref="files" :loc="loc" :opts="opts"
                @action="$emit('action', $event)" @file:select="$emit('select', $event)"/>
        </div>
        <project-errors :errors="buildErrors"
            @goto-log="$emit('error:goto-log', $event)"
            @goto-source="$emit('error:goto-source', $event)"/>
        <project-p2p/>
    </div>  
</template>

<script lang="ts">
import ProjectHeader from './project-header.vue';
import ProjectFiles from './project-files.vue';
import ProjectErrors from './project-errors.vue';
import ProjectP2P from './project-p2p.vue';

export default {
    data: () => ({loc: null, opts: null, name: 'project', clientState: undefined,
                  projects: [], buildStatus: undefined, buildErrors: []}),
    components: { ProjectHeader, ProjectFiles, ProjectErrors, 'project-p2p': ProjectP2P }
}
</script>
