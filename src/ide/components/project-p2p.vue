<template>
    <div class="project-p2p ide-pane-section">
        <div class="bar">P2P Collab</div>
        <div>
            <button-join :channel="channel"/>
            <list-of-peers ref="peers"></list-of-peers>
        </div>
    </div>
</template>

<script>
import ButtonJoin from 'ronin-p2p/src/ui/components/button-join.vue';
import ListOfPeers from 'ronin-p2p/src/ui/components/list-of-peers.vue';

export default {
    computed: {
        channel() {
            return this.$root.clientState?.p2pWorkspace;
        }
    },
    components: { ButtonJoin, ListOfPeers }
}
</script>