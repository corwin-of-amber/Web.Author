<template>
    <div class="project-view">
        <project-header ref="header" :name="name" :build-status="buildStatus"
            :projects="projects" @action="action" @build="build"/>
        <project-files ref="files" :loc="loc" :opts="opts"
            @action="action" @file:select="select"/>
    </div>  
</template>

<script>
import ProjectHeader from './project-header.vue';
import ProjectFiles from './project-files.vue';

export default {
    data: () => ({loc: null, opts: null, name: 'project', clientState: undefined,
                  projects: [], buildStatus: undefined}),
    components: {ProjectHeader, ProjectFiles}
}
</script>
