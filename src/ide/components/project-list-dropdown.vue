<template>
    <context-menu ref="l" @action="action">
        <item v-for="item in items" :key="keyOf(item)"
            @action="action({type: 'open', item})">{{item.name}}</item>
        <hr/>
        <item name="new">New Project</item>
        <item name="open...">Open...</item>
        <item name="refresh">Refresh</item>
        <item name="download:source">Download Sources</item>
        <item name="download:built">Download Compiled</item>
    </context-menu>
</template>

<script>
import ContextMenu
    from '../../../packages/context-menu/context-menu.vue';


export default {
    props: ['items'],
    methods: {
        keyOf(item) {
            return item.loc ? `${item.loc.scheme}:${item.loc.path}`
                            : item.name;
        },
        open() { this.$refs.l.open(this.position()); },
        toggle() { this.$refs.l.toggle(this.position()); },
        position() {
            var box = this.$el.parentElement.getBoundingClientRect();
            return {clientX: box.left, clientY: box.bottom};
        },
        action(ev) { this.$emit('action', ev); }
    },
    components: { ContextMenu, item: ContextMenu.Item }
}
</script>

<style>

</style>