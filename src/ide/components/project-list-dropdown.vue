<template>
    <vue-context ref="l">
        <li v-for="item in items" :key="keyOf(item)">
            <a @click="action('open', {item})">{{item.name}}</a>
        </li>
        <hr/>
        <li><a @click="action('refresh')">Refresh</a></li>
        <li><a @click="action('open...')">Open...</a></li>
    </vue-context>  
</template>

<script>
import { VueContext } from 'vue-context';

export default {
    props: ['items'],
    methods: {
        keyOf(item) {
            return item.loc ? `${item.loc.scheme}:${item.loc.path}`
                            : item.name;
        },
        toggle() {
            if (!this.$refs.l.show)
                this.$refs.l.open(this.position());
            else this.$refs.l.close();
        },
        position() {
            var box = this.$el.parentElement.getBoundingClientRect();
            return {clientX: box.left, clientY: box.bottom};
        },
        action(type, attr) {
            this.$emit('action', {type, ...attr});
        }
    },
    components: {VueContext}
}
</script>

<style>

</style>