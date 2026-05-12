package pl.eengine.signaturetool.crypto;

import org.w3c.dom.Node;
import xades4j.UnsupportedAlgorithmException;
import xades4j.algorithms.Algorithm;
import xades4j.algorithms.CanonicalXMLWithoutComments;
import xades4j.algorithms.GenericAlgorithm;
import xades4j.providers.AlgorithmsProviderEx;

import java.util.Map;

public class Sha256AlgorithmsProvider implements AlgorithmsProviderEx {
    private static final Map<String, Algorithm> SIGNATURE_ALGORITHMS =
            Map.of("RSA", new GenericAlgorithm("http://www.w3.org/2001/04/xmldsig-more#rsa-sha256", new Node[0]));

    @Override
    public Algorithm getSignatureAlgorithm(String keyAlgorithmName) throws UnsupportedAlgorithmException {
        Algorithm algorithm = SIGNATURE_ALGORITHMS.get(keyAlgorithmName);
        if (algorithm == null) {
            throw new UnsupportedAlgorithmException("Signature algorithm not supported by the provider", keyAlgorithmName);
        }

        return algorithm;
    }

    @Override
    public Algorithm getCanonicalizationAlgorithmForSignature() {
        return new CanonicalXMLWithoutComments();
    }

    @Override
    public Algorithm getCanonicalizationAlgorithmForTimeStampProperties() {
        return new CanonicalXMLWithoutComments();
    }

    @Override
    public String getDigestAlgorithmForDataObjsReferences() {
        return "http://www.w3.org/2001/04/xmlenc#sha256";
    }

    @Override
    public String getDigestAlgorithmForReferenceProperties() {
        return "http://www.w3.org/2001/04/xmlenc#sha256";
    }

    @Override
    public String getDigestAlgorithmForTimeStampProperties() {
        return "http://www.w3.org/2001/04/xmlenc#sha256";
    }
}

