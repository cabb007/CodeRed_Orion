import test from 'node:test';
import assert from 'node:assert/strict';
import { decide, validateSubmission, REWARDS } from '../../server/policy.mjs';
import { buildSubmission, validateReceipt } from '../src/verification.js';

const id = 'a1111111-1111-4111-8111-111111111111';
const receiptId = 'b1111111-1111-4111-8111-111111111111';
const assessment = { itemName:'Can', material:'aluminum', evidenceQuality:'high', binType:'recycling',
  localAcceptance:'recyclable_here', acceptanceEvidence:'printed_label', labelEvidence:'Cans',
  contaminated:false, suspicious:false, explanation:'Visual match.', tip:'Check local rules.' };
const receipt = a => ({...decide(a,id),receiptId,reviewedAt:new Date(100_000).toISOString()});

test('mobile two-photo submissions are accepted by the shared server contract',()=>{
  const frames=['bin','item'].map((role,i)=>({role,capturedAt:new Date(100_000+i*1000).toISOString(),data:'/9j/'+['A','B'][i].repeat(200)}));
  const submission=buildSubmission(id,frames,{now:103_000});
  assert.deepEqual(validateSubmission(submission,103_000).photos.map(p=>p.role),['bin','item']);
  assert.throws(()=>buildSubmission(id,[...frames,{...frames[1],role:'disposal'}],{now:103_000}));
});
test('mobile accepts current server receipts for every rewarded material and supported evidence',()=>{
  for(const [material,leaves] of Object.entries(REWARDS).filter(([,n])=>n>0)){
    for(const acceptanceEvidence of ['printed_label','material_icon','nearby_sign','bin_appearance']){
      const result=receipt({...assessment,material,acceptanceEvidence});
      assert.equal(validateReceipt(result,id).leaves,leaves);
      if(acceptanceEvidence==='bin_appearance') assert.equal(result.localAcceptance,'likely_compatible');
    }
  }
});
test('unclear or incompatible bin evidence never becomes a mobile reward',()=>{
  for(const change of [{binType:'unknown'},{binType:'general_waste'},{acceptanceEvidence:'none'},{contaminated:true},{suspicious:true}]){
    const result=receipt({...assessment,...change});
    assert.equal(validateReceipt(result,id).leaves,0);
    if (change.binType || change.acceptanceEvidence) {
      assert.throws(()=>validateReceipt({...result,status:'approved',leaves:30,cleanup:1},id));
    }
  }
});
