<template>
    <div class="project-view">
        <div class="ide-pane-section project-main">
            <project-header ref="header" :name="name" :build-status="buildStatus"
                :projects="projects" @action="action" @build="build"/>
            <project-files ref="files" :loc="loc" :opts="opts"
                @action="action" @file:select="select"/>
        </div>
        <project-errors :errors="buildErrors"/>
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
