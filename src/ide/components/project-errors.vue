<template>
    <div class="project-errors ide-pane-section">
        <div class="bar">Build Errors</div>
        <div>
            <table>
                <tr v-for="error in errors">
                    <th>{{basename(error.at.filename)}}:{{error.at.line}}</th>
                    <td><div>{{error.message}}</div></td>
                </tr>
            </table>
        </div>
    </div>
</template>

<script lang="ts">
export default {
    props: ['errors'],
    methods: {
        basename(fn: string) {
            return fn.match(/[^/]*$/)[0];
        }
    }
}
</script>

<style scoped>
th, td { vertical-align: baseline; }
</style>