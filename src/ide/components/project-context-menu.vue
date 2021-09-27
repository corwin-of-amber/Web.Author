<template>
    <context-menu ref="m" @action="action">
        <item name="new-file">New File</item>
        <item name="rename">Rename</item>
        <item name="delete">Delete</item>
        <hr>
        <item name="refresh">Refresh</item>
    </context-menu>
</template>

<script>
import ContextMenu
    from '../../../packages/context-menu/context-menu.vue';


export default {
    methods: {
        open(ev, action) { this.$refs.m.open(ev, action); },
        action(ev) { this.$emit('action', ev); }
    },
    components: { ContextMenu, item: ContextMenu.Item }
}
</script>
