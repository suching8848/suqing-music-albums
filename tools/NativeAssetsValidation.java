import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.Set;
import java.util.Map;
import java.util.HashMap;
import zombie.scripting.ScriptParser;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.GameSoundScript;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;

/** Native structural parser checks, not a complete asset/game load. */
public final class NativeAssetsValidation {
    private static String render(ScriptParser.Block block) {
        StringBuilder out = new StringBuilder(block.type);
        if (block.id != null) out.append(' ').append(block.id);
        out.append(" {\n");
        for (var value : block.values) out.append(value.string).append(",\n");
        for (var child : block.children) out.append(render(child));
        return out.append("}\n").toString();
    }
    public static void main(String[] args) throws Exception {
        int count = 0, privateSounds = 0, itemWeights = 0;
        Set<String> ids = new HashSet<>();
        Map<String, Float> sourceWeights = new HashMap<>(), candidateWeights = new HashMap<>();
        var modField = ScriptManager.class.getDeclaredField("currentLoadFileMod");
        modField.setAccessible(true); modField.set(null, "pz-vanilla");
        for (int index = 0; index < args.length; index++) {
            String file = args[index];
            boolean sourceOnly = file.equals("--source-items");
            if (sourceOnly) file = args[++index];
            String source = Files.readString(Path.of(file), StandardCharsets.UTF_8).replace("\ufeff", "");
            var root = ScriptParser.parse(ScriptParser.stripComments(source));
            for (var module : root.children) {
                if (!"module".equals(module.type) || module.id == null || module.id.isBlank())
                    throw new AssertionError("Expected named module: " + file);
                for (var entry : module.children) {
                    if (sourceOnly && !("item".equals(entry.type) && (entry.id.startsWith("Cassette") || entry.id.startsWith("Vinyl")))) continue;
                    String key = module.id + "." + entry.type + "." + entry.id;
                    if (entry.id == null || entry.id.isBlank() || !ids.add(key))
                        throw new AssertionError("Missing/duplicate script ID: " + key);
                    if (!sourceOnly) count++;
                    if ("item".equals(entry.type)) {
                        ScriptModule scriptModule = new ScriptModule(); scriptModule.name = module.id;
                        Item item = new Item(); item.setModule(scriptModule);
                        // The isolated native weight parser avoids texture/world registry
                        // initialization. The full unmodified block was parsed above.
                        var weight = entry.values.stream().filter(v -> v.getKey().trim().equalsIgnoreCase("Weight")).findFirst().orElseThrow();
                        item.Load(entry.id, "item " + entry.id + " { Weight=" + weight.getValue().trim() + ", }");
                        String fullType = module.id + "." + entry.id;
                        (sourceOnly ? sourceWeights : candidateWeights).put(fullType, item.getActualWeight());
                        if (!sourceOnly && Math.abs(item.getActualWeight() - 0.02f) > 0.000001f)
                            throw new AssertionError("Unexpected native collection weight: " + fullType + "=" + item.getActualWeight());
                        itemWeights++;
                    }
                    if ("sound".equals(entry.type)) {
                        GameSoundScript script = new GameSoundScript();
                        script.Load(entry.id, render(entry));
                        var sound = script.gameSound;
                        if (!entry.id.startsWith("SQM_Private_") || sound.is3d || sound.loop
                                || sound.clips.size() != 1 || sound.clips.getFirst().getFile() == null)
                            throw new AssertionError("Private sound did not load as nonlooping 2D file: " + entry.id);
                        if (!"Ambient".equals(sound.getMasterName()) || sound.clips.getFirst().getVolume() < 0)
                            throw new AssertionError("Unexpected source gain/master: " + entry.id);
                        privateSounds++;
                    }
                }
            }
        }
        if (count == 0) throw new AssertionError("No script blocks parsed");
        for (var candidate : candidateWeights.entrySet()) {
            String medium = candidate.getKey().contains(".Cassette") ? "Cassette" : "Vinyl";
            for (var source : sourceWeights.entrySet()) {
                if (source.getKey().contains("." + medium) && Math.abs(source.getValue() - candidate.getValue()) > 0.000001f)
                    throw new AssertionError("Collection weight differs from current original " + candidate.getKey() + " vs " + source.getKey());
            }
        }
        System.out.println("NATIVE_SCRIPT_BLOCKS=" + count);
        System.out.println("NATIVE_2D_SOUNDS=" + privateSounds);
        System.out.println("NATIVE_ITEM_WEIGHTS=" + itemWeights);
    }
}
