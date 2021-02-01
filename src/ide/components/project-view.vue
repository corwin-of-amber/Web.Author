<template>
    <div class="project-view">
        <project-header ref="header" name="project" :build-status="buildStatus"
        :projects="projects" @open="open" @build="build"/>
        <project-files ref="files" :path="path" @file:select="select"/>
    </div>  
</template>

<script>
import ProjectHeader from './project-header.vue';
import ProjectFiles from './project-files.vue';

export default {
    data: () => ({path: null, clientState: undefined, projects: [], buildStatus: undefined}),
    components: {ProjectHeader, ProjectFiles}
}
</script>
