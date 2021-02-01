<template>
    <vue-context ref="l">
        <li v-for="item in items" :key="item.name"><a @click="open(item)">{{item.name}}</a></li>
    </vue-context>  
</template>

<script>
import { VueContext } from 'vue-context';

export default {
    props: ['items'],
    methods: {
        toggle() {
            if (!this.$refs.l.show)
                this.$refs.l.open(this.position());
            else this.$refs.l.close();
        },
        position() {
            var box = this.$el.parentElement.getBoundingClientRect();
            return {clientX: box.left, clientY: box.bottom};
        },
        open(item) {
            this.$emit('open', item);
        }
    },
    components: {VueContext}
}
</script>

<style>

</style>