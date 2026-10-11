import React, { useState } from 'react';
import { Platform, TextInput } from 'react-native';
import { useGame } from './GameProvider';
import { binRequest } from './communityBins';
import { connection } from './verification';
import { Button, Label, Panel, styles } from './ui';
export default function BinConnection({onClose,onSaved}) {
  const store = useGame(); const [url,setURL] = useState(store.preferences.url), [token,setToken] = useState(store.token), [busy,setBusy] = useState(false), [error,setError] = useState('');
  const save = async () => { setBusy(true); setError(''); try {
    store.assertReal();
    const config = connection(url,token), status = await binRequest(config.url,config.token,store.installationId,'/v1/status');
    if (status.service !== 'ecogotchi' || status.communityBins !== true) throw new Error('Update your EcoGotchi server to enable community bin landmarks.');
    await store.savePreferences({...store.preferences,url:config.url},config.token); onSaved();
  } catch (e) { setError(e.message); } finally { setBusy(false); } };
  return <Panel style={styles.stack}><Label style={styles.subheading}>Community map server</Label>
    <Label>Connect phones to the same EcoGotchi server to share landmarks. Bin sharing works without a Gemini key. This uses the same server connection as AI review.</Label>
    <TextInput accessibilityLabel="Community server HTTPS address" autoCapitalize="none" autoCorrect={false} value={url} onChangeText={setURL} placeholder="https://your-server.example" style={styles.input} />
    <TextInput accessibilityLabel="Community server access token" autoCapitalize="none" autoCorrect={false} value={token} onChangeText={setToken} secureTextEntry placeholder="ECOGOTCHI_ACCESS_TOKEN" style={styles.input} />
    {Platform.OS === 'web' && <Label>Shared landmarks are available in the phone app. Browser previews save local drafts.</Label>}
    {!!error && <Label style={styles.error}>{error}</Label>}
    <Button disabled={busy || store.isDeveloperMode || Platform.OS === 'web'} onPress={save}>{busy ? 'Checking…' : 'Check and save connection'}</Button>
    <Button secondary disabled={busy} onPress={onClose}>Close</Button></Panel>;
}
