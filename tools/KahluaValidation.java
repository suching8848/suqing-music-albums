import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.j2se.KahluaTableImpl;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaCallFrame;

/** Executes production Lua in the installed game's Kahlua; no game launcher. */
public final class KahluaValidation {
    private static int roundTrips;

    private static final JavaFunction ROUND_TRIP = new JavaFunction() {
        @Override public int call(LuaCallFrame frame, int count) {
            if (count != 1 || !(frame.get(0) instanceof KahluaTableImpl source))
                throw new IllegalArgumentException("nativeRoundTrip expects one game KahluaTableImpl");
            try {
                ByteBuffer buffer = ByteBuffer.allocate(4 * 1024 * 1024);
                source.save(buffer);
                buffer.flip();
                KahluaTableImpl restored = new KahluaTableImpl(new HashMap<>());
                restored.load(buffer, 241);
                if (buffer.hasRemaining()) throw new AssertionError("Unconsumed serialized state");
                roundTrips++;
                frame.push(restored);
                return 1;
            } catch (Exception ex) { throw new RuntimeException("Native table round trip failed", ex); }
        }
    };

    public static void main(String[] args) throws Exception {
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        env.rawset("nativeRoundTrip", ROUND_TRIP);
        Map<String, byte[]> oracle = new HashMap<>();
        env.rawset("nativeUTF8Hex", (JavaFunction)(frame, count) -> {
            if (count != 1 || !(frame.get(0) instanceof String value)) throw new IllegalArgumentException("nativeUTF8Hex expects String");
            frame.push(HexFormat.of().formatHex(value.getBytes(StandardCharsets.UTF_8)));
            return 1;
        });
        env.rawset("nativeExpectedText", (JavaFunction)(frame, count) -> {
            byte[] expected = oracle.get(String.valueOf(frame.get(0)));
            if (expected == null) throw new IllegalArgumentException("Unknown external UTF8 oracle: " + frame.get(0));
            frame.push(new String(expected, StandardCharsets.UTF_8));
            return 1;
        });
        env.rawset("nativeLookupText", (JavaFunction)(frame, count) -> {
            byte[] expected = oracle.get(String.valueOf(frame.get(0)));
            frame.push(expected == null ? null : new String(expected, StandardCharsets.UTF_8));
            return 1;
        });
        env.rawset("nativeAssertUTF8", (JavaFunction)(frame, count) -> {
            if (count != 2 || !(frame.get(0) instanceof String actual)) throw new IllegalArgumentException("nativeAssertUTF8 expects String, oracleKey");
            String key = String.valueOf(frame.get(1));
            byte[] expected = oracle.get(key);
            if (expected == null || !Arrays.equals(actual.getBytes(StandardCharsets.UTF_8), expected))
                throw new AssertionError("UTF8 mismatch " + key + " actual=" + HexFormat.of().formatHex(actual.getBytes(StandardCharsets.UTF_8))
                        + " expected=" + (expected == null ? "missing" : HexFormat.of().formatHex(expected)));
            frame.push(true);
            return 1;
        });
        env.rawset("print", (JavaFunction)(frame, count) -> {
            StringBuilder message = new StringBuilder();
            for (int i = 0; i < count; i++) {
                if (i > 0) message.append('\t');
                message.append(String.valueOf(frame.get(i)));
            }
            System.out.println(message);
            return 0;
        });
        for (int index = 0; index < args.length; index++) {
            String file = args[index];
            if (file.equals("--oracle")) {
                for (String line : Files.readAllLines(Path.of(args[++index]), StandardCharsets.US_ASCII)) {
                    int tab = line.indexOf('\t');
                    if (tab < 1) throw new AssertionError("Invalid external UTF8 oracle line");
                    oracle.put(line.substring(0, tab), HexFormat.of().parseHex(line.substring(tab + 1)));
                }
                continue;
            }
            String source = Files.readString(Path.of(file), StandardCharsets.UTF_8).replace("\ufeff", "");
            Object closure = LuaCompiler.loadstring(source, file, env);
            Object[] result = thread.pcall(closure, new Object[0]);
            System.out.println(file + ": " + Arrays.toString(result));
            if (!Boolean.TRUE.equals(result[0])) throw new AssertionError("Kahlua failed: " + Arrays.toString(result));
        }
        Object assertions = env.rawget("CHECKS");
        if (assertions instanceof Number number) System.out.println("ASSERTIONS=" + number.intValue());
        System.out.println("NATIVE_TABLE_ROUND_TRIPS=" + roundTrips);
    }
}
