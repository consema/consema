// Consema's repository-owned Java SE 25 Properties differential adapter.
// Output is ASCII TSV so exact Java UTF-16 code units survive transport.

import java.io.ByteArrayInputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Properties;

public final class PropertiesOracle {
    private static final char[] HEX = "0123456789abcdef".toCharArray();

    private PropertiesOracle() {}

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && args[0].equals("--runtime")) {
            runtimeFacts();
            return;
        }
        if (args.length != 3) {
            throw new IllegalArgumentException(
                    "usage: PropertiesOracle.java <reader|latin1> <bytes|hex> <input>");
        }

        byte[] bytes = Files.readAllBytes(Path.of(args[2]));
        if (args[1].equals("hex")) {
            bytes = decodeHex(bytes);
        } else if (!args[1].equals("bytes")) {
            throw new IllegalArgumentException("unknown storage: " + args[1]);
        }
        System.out.println("input-sha256\t" + sha256(bytes));

        Properties properties = new Properties();
        try {
            if (args[0].equals("reader")) {
                properties.load(new InputStreamReader(
                        new ByteArrayInputStream(bytes), StandardCharsets.UTF_8));
            } else if (args[0].equals("latin1")) {
                properties.load(new ByteArrayInputStream(bytes));
            } else {
                throw new IllegalArgumentException("unknown profile: " + args[0]);
            }
        } catch (IllegalArgumentException error) {
            System.out.println("failed\t" + error.getClass().getName());
            return;
        }

        System.out.println("complete");
        List<String> keys = new ArrayList<>(properties.stringPropertyNames());
        keys.sort(Comparator.naturalOrder());
        for (String key : keys) {
            System.out.println(
                    "entry\t" + utf16Hex(key) + "\t" + utf16Hex(properties.getProperty(key)));
        }
    }

    private static void runtimeFacts() {
        System.out.println("java.runtime.name\t" + System.getProperty("java.runtime.name"));
        System.out.println("java.runtime.version\t" + System.getProperty("java.runtime.version"));
        System.out.println("java.vendor\t" + System.getProperty("java.vendor"));
        System.out.println("java.vm.name\t" + System.getProperty("java.vm.name"));
        System.out.println("os.name\t" + System.getProperty("os.name"));
        System.out.println("os.version\t" + System.getProperty("os.version"));
        System.out.println("os.arch\t" + System.getProperty("os.arch"));
    }

    private static String utf16Hex(String value) {
        StringBuilder output = new StringBuilder(value.length() * 4);
        for (int index = 0; index < value.length(); index++) {
            int unit = value.charAt(index);
            output.append(HEX[(unit >>> 12) & 0x0f]);
            output.append(HEX[(unit >>> 8) & 0x0f]);
            output.append(HEX[(unit >>> 4) & 0x0f]);
            output.append(HEX[unit & 0x0f]);
        }
        return output.toString();
    }

    private static String sha256(byte[] bytes) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder output = new StringBuilder(digest.length * 2);
        for (byte item : digest) {
            int value = item & 0xff;
            output.append(HEX[value >>> 4]);
            output.append(HEX[value & 0x0f]);
        }
        return output.toString();
    }

    private static byte[] decodeHex(byte[] source) {
        List<Integer> digits = new ArrayList<>();
        for (byte item : source) {
            int value = item & 0xff;
            if (value == ' ' || value == '\t' || value == '\r' || value == '\n') {
                continue;
            }
            digits.add(hexNibble(value));
        }
        if ((digits.size() & 1) != 0) {
            throw new IllegalArgumentException("hex input has an odd digit count");
        }
        byte[] bytes = new byte[digits.size() / 2];
        for (int index = 0; index < bytes.length; index++) {
            bytes[index] = (byte) ((digits.get(index * 2) << 4) | digits.get(index * 2 + 1));
        }
        return bytes;
    }

    private static int hexNibble(int value) {
        if (value >= '0' && value <= '9') {
            return value - '0';
        }
        if (value >= 'a' && value <= 'f') {
            return value - 'a' + 10;
        }
        throw new IllegalArgumentException("hex input is not canonical lowercase hexadecimal");
    }
}
