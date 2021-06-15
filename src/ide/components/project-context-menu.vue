<template>
    <vue-context ref="m">
        <li><a name="new-file" @click="action">New File</a></li>
        <li><a name="rename" @click="action">Rename</a></li>
        <li><a name="delete" @click="action">Delete</a></li>
        <hr>
        <li><a name="refresh" @click="action">Refresh</a></li>
    </vue-context>  
</template>

<script>
import { VueContext } from 'vue-context';

export default {
    methods: {
        open(ev, for_) { this.for = for_; this.$refs.m.open(ev); },
        action(ev) { this.$emit('action', {name: ev.currentTarget.name, for: this.for}); }
    },
    components: {VueContext}
}
</script>
